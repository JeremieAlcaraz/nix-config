#!/usr/bin/env bash
# Script de diagnostic pour le workflow de mise à jour n8n
set -euo pipefail

echo "🔍 Diagnostic du système de mise à jour n8n"
echo "==========================================="
echo ""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Vérifier l'image actuelle
echo "📦 1. Image n8n actuelle dans n8n.nix :"
echo "----------------------------------------"
CURRENT_IMAGE=$(grep -oP 'image = "docker.io/n8nio/n8n:\K[^"]+' hosts/whitelily/n8n.nix || echo "NOT_FOUND")
echo "   Image : docker.io/n8nio/n8n:$CURRENT_IMAGE"

if [[ "$CURRENT_IMAGE" == *"@sha256:"* ]]; then
  CURRENT_DIGEST=$(echo "$CURRENT_IMAGE" | grep -oP '@sha256:\K[a-f0-9]+')
  echo -e "   ${GREEN}✓${NC} Digest trouvé : $CURRENT_DIGEST"
else
  echo -e "   ${YELLOW}⚠${NC} Pas de digest SHA256 (l'image n'a jamais été mise à jour par le workflow)"
  CURRENT_DIGEST="none"
fi
echo ""

# 2. Récupérer le dernier digest depuis Docker Hub
echo "🐳 2. Dernier digest de n8n:next sur Docker Hub :"
echo "--------------------------------------------------"

# Obtenir un token d'authentification Docker Hub
TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:n8nio/n8n:pull" | jq -r .token)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo -e "   ${RED}✗${NC} Impossible d'obtenir un token Docker Hub"
  exit 1
fi

# Récupérer le manifest de l'image next
MANIFEST=$(curl -s -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  "https://registry-1.docker.io/v2/n8nio/n8n/manifests/next")

# Debug : afficher le manifest
echo "   Debug - Taille du manifest : $(echo "$MANIFEST" | wc -c) bytes"

# Extraire le digest du manifest (essayer différentes méthodes)
LATEST_DIGEST=$(echo "$MANIFEST" | jq -r '.config.digest' 2>/dev/null | cut -d: -f2)

# Si ça échoue, essayer avec le digest du manifest lui-même
if [ -z "$LATEST_DIGEST" ] || [ "$LATEST_DIGEST" = "null" ] || [ "$LATEST_DIGEST" = "" ]; then
  echo "   Essai avec Docker-Content-Digest header..."
  DIGEST_HEADER=$(curl -sI -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    "https://registry-1.docker.io/v2/n8nio/n8n/manifests/next" | grep -i "docker-content-digest" | cut -d' ' -f2 | tr -d '\r' | cut -d: -f2)
  LATEST_DIGEST="$DIGEST_HEADER"
fi

if [ -z "$LATEST_DIGEST" ] || [ "$LATEST_DIGEST" = "null" ] || [ "$LATEST_DIGEST" = "" ]; then
  echo -e "   ${RED}✗${NC} Impossible de récupérer le digest de n8n:next"
  echo "   Manifest reçu : $(echo "$MANIFEST" | head -c 200)"
  exit 1
fi

echo -e "   ${GREEN}✓${NC} Digest : $LATEST_DIGEST"
echo ""

# 3. Comparer les versions
echo "🔄 3. Comparaison des versions :"
echo "--------------------------------"
echo "   Actuelle : ${CURRENT_DIGEST}"
echo "   Dernière : ${LATEST_DIGEST}"
echo ""

if [ "$CURRENT_DIGEST" = "$LATEST_DIGEST" ]; then
  echo -e "   ${GREEN}✓ Déjà à jour !${NC}"
  UPDATE_NEEDED="false"
else
  echo -e "   ${YELLOW}⚠ Mise à jour disponible !${NC}"
  UPDATE_NEEDED="true"
fi
echo ""

# 4. Vérifier le workflow GitHub Actions
echo "⚙️  4. Vérification du workflow GitHub Actions :"
echo "------------------------------------------------"

# Vérifier si le fichier workflow existe
if [ -f ".github/workflows/update-n8n-next.yml" ]; then
  echo -e "   ${GREEN}✓${NC} Fichier workflow présent"

  # Extraire la cron schedule
  CRON_SCHEDULE=$(grep -A1 "schedule:" .github/workflows/update-n8n-next.yml | grep "cron:" | sed "s/.*cron: '\(.*\)'/\1/")
  echo "   Planification : $CRON_SCHEDULE (tous les jours à 2h UTC)"
else
  echo -e "   ${RED}✗${NC} Fichier workflow manquant"
fi
echo ""

# 5. Résumé et recommandations
echo "📊 5. Résumé et recommandations :"
echo "---------------------------------"

if [ "$UPDATE_NEEDED" = "true" ]; then
  echo -e "${YELLOW}⚠ UNE MISE À JOUR EST DISPONIBLE${NC}"
  echo ""
  echo "Vérifications à faire sur GitHub :"
  echo ""
  echo "   1️⃣  Vérifier les exécutions du workflow :"
  echo "      https://github.com/JeremieAlcaraz/nix-config/actions/workflows/update-n8n-next.yml"
  echo ""
  echo "   2️⃣  Vérifier le secret N8N_UPDATE_TOKEN :"
  echo "      https://github.com/JeremieAlcaraz/nix-config/settings/secrets/actions"
  echo ""
  echo "   3️⃣  Vérifier les PRs n8n ouvertes :"
  echo "      https://github.com/JeremieAlcaraz/nix-config/pulls?q=is%3Apr+label%3An8n"
  echo ""
  echo "Options :"
  echo ""
  echo "   A) Si le workflow ne fonctionne pas, vous pouvez demander à Claude de :"
  echo "      - Mettre à jour manuellement le fichier n8n.nix avec le nouveau digest"
  echo "      - Créer un commit et le pusher"
  echo ""
  echo "   B) Tester manuellement le workflow depuis GitHub :"
  echo "      - Aller sur la page Actions → update-n8n-next → Run workflow"
  echo ""
else
  echo -e "${GREEN}✓ AUCUNE MISE À JOUR NÉCESSAIRE${NC}"
  echo ""
  echo "Votre installation n8n est à jour !"
  echo ""
  echo "Pour vérifier quand même le workflow :"
  echo "   https://github.com/JeremieAlcaraz/nix-config/actions/workflows/update-n8n-next.yml"
fi
echo ""
echo "==========================================="
