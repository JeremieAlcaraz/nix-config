#!/usr/bin/env bash
set -euo pipefail

echo "╔══════════════════════════════════╗"
echo "║  DIAGNOSTIC n8n AUTOMATIQUE      ║"
echo "╚══════════════════════════════════╝"
echo ""

# 1. Services
echo "📊 Services"
systemctl is-active postgresql >/dev/null && echo "✅ PostgreSQL actif" || echo "❌ PostgreSQL inactif"
systemctl is-active podman-n8n >/dev/null && echo "✅ n8n actif" || echo "❌ n8n inactif"
systemctl is-active caddy >/dev/null && echo "✅ Caddy actif" || echo "❌ Caddy inactif"
systemctl is-active cloudflared-tunnel >/dev/null && echo "✅ Cloudflared actif" || echo "❌ Cloudflared inactif"
echo ""

# 2. Secrets
echo "🔐 Secrets (longueur en caractères)"
if [ -f /run/secrets/n8n/encryption_key ]; then
    ENC_LEN=$(sudo cat /run/secrets/n8n/encryption_key | wc -c)
    echo "Encryption key: $ENC_LEN caractères"
    # Vérifier les guillemets dans le secret
    if sudo cat /run/secrets/n8n/encryption_key | grep -q '"'; then
        echo "⚠️  WARNING: Le secret encryption_key contient des guillemets!"
    fi
else
    echo "❌ Secret encryption_key introuvable"
fi

if [ -f /run/secrets/n8n/db_password ]; then
    DB_LEN=$(sudo cat /run/secrets/n8n/db_password | wc -c)
    echo "DB password: $DB_LEN caractères"
    # Vérifier les guillemets dans le secret
    if sudo cat /run/secrets/n8n/db_password | grep -q '"'; then
        echo "⚠️  WARNING: Le secret db_password contient des guillemets!"
    fi
else
    echo "❌ Secret db_password introuvable"
fi
echo ""

# 3. Fichier .env
echo "⚙️  Variables .env"
if [ -f /run/n8n/n8n.env ]; then
    ENCRYPTION=$(sudo cat /run/n8n/n8n.env | grep "N8N_ENCRYPTION_KEY=" | cut -d= -f2)
    DB_PASS=$(sudo cat /run/n8n/n8n.env | grep "DB_POSTGRESDB_PASSWORD=" | cut -d= -f2)

    echo "Encryption key: [$ENCRYPTION] (${#ENCRYPTION} chars)"
    echo "DB password: [$DB_PASS] (${#DB_PASS} chars)"

    # Vérifier les guillemets dans les valeurs
    if [[ "$DB_PASS" == \"*\" ]] || [[ "$DB_PASS" == *\" ]]; then
        echo "❌ ERREUR: Le mot de passe contient des guillemets!"
        echo "   Valeur extraite: '$DB_PASS'"
        echo "   Solution: Vérifier le script n8n-envfile"
    else
        echo "✅ Pas de guillemets parasites dans le mot de passe"
    fi

    if [[ "$ENCRYPTION" == \"*\" ]] || [[ "$ENCRYPTION" == *\" ]]; then
        echo "⚠️  WARNING: La clé d'encryption contient des guillemets!"
    fi
else
    echo "❌ Fichier /run/n8n/n8n.env introuvable"
fi
echo ""

# 4. Test connexion DB
echo "🗄️  Test connexion PostgreSQL"
if [ -f /run/n8n/n8n.env ]; then
    DB_PASS=$(sudo cat /run/n8n/n8n.env | grep "DB_POSTGRESDB_PASSWORD=" | cut -d= -f2)
    if PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U n8n -d n8n -c "SELECT 1;" >/dev/null 2>&1; then
        echo "✅ Connexion DB réussie avec le mot de passe du .env"
    else
        echo "❌ Connexion DB échouée"
        echo "   Tentative de diagnostic..."

        # Essayer de se connecter avec le mot de passe direct du secret
        if [ -f /run/secrets/n8n/db_password ]; then
            SECRET_PASS=$(sudo cat /run/secrets/n8n/db_password | tr -d '\n"' | xargs)
            echo "   Test avec le secret nettoyé: [$SECRET_PASS]"
            if PGPASSWORD="$SECRET_PASS" psql -h 127.0.0.1 -U n8n -d n8n -c "SELECT 1;" >/dev/null 2>&1; then
                echo "   ✅ Connexion réussie avec le secret nettoyé"
                echo "   ⚠️  Le problème vient du script n8n-envfile!"
            else
                echo "   ❌ Connexion échouée même avec le secret nettoyé"
            fi
        fi
    fi
else
    echo "⚠️  Impossible de tester: fichier .env manquant"
fi
echo ""

# 5. Dernières erreurs
echo "📝 Dernières erreurs n8n"
if sudo journalctl -u podman-n8n.service -n 20 --no-pager | grep -i "error\|failed\|crash" | tail -5; then
    echo ""
else
    echo "✅ Aucune erreur récente"
fi
echo ""

# 6. Port local
echo "🌐 Test port local"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "401" ]] || [[ "$HTTP_CODE" == "200" ]]; then
    echo "✅ n8n répond sur localhost:5678 (HTTP $HTTP_CODE)"
elif [[ "$HTTP_CODE" == "000" ]]; then
    echo "❌ n8n ne répond pas (connexion refusée)"
else
    echo "⚠️  n8n répond avec un code inattendu: HTTP $HTTP_CODE"
fi
echo ""

# 7. Résumé
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "RÉSUMÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ALL_OK=true

if ! systemctl is-active postgresql >/dev/null; then
    echo "❌ PostgreSQL n'est pas actif"
    ALL_OK=false
fi

if ! systemctl is-active podman-n8n >/dev/null; then
    echo "❌ n8n n'est pas actif"
    ALL_OK=false
fi

if [ -f /run/n8n/n8n.env ]; then
    DB_PASS=$(sudo cat /run/n8n/n8n.env | grep "DB_POSTGRESDB_PASSWORD=" | cut -d= -f2)
    if [[ "$DB_PASS" == \"*\" ]] || [[ "$DB_PASS" == *\" ]]; then
        echo "❌ Guillemets détectés dans le mot de passe"
        ALL_OK=false
    fi

    if ! PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U n8n -d n8n -c "SELECT 1;" >/dev/null 2>&1; then
        echo "❌ Impossible de se connecter à PostgreSQL"
        ALL_OK=false
    fi
fi

if [[ "$HTTP_CODE" != "401" ]] && [[ "$HTTP_CODE" != "200" ]]; then
    echo "❌ n8n ne répond pas correctement"
    ALL_OK=false
fi

if $ALL_OK; then
    echo "✅ Tout est OK ! n8n fonctionne correctement."
else
    echo ""
    echo "🔧 Actions suggérées:"
    echo "   1. Vérifier les logs: sudo journalctl -u podman-n8n.service -f"
    echo "   2. Vérifier les secrets: sudo cat /run/secrets/n8n/db_password | od -c"
    echo "   3. Vérifier le .env: sudo cat /run/n8n/n8n.env | grep PASSWORD"
    echo "   4. Rebuilder: sudo nixos-rebuild switch --flake /etc/nixos#whitelily"
fi

echo ""
