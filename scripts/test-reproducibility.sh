#!/usr/bin/env bash
# Script pour tester la reproductibilité des installations NixOS
# Ce script doit être exécuté sur la VM installée

set -euo pipefail

echo "=== Test de reproductibilité NixOS ==="
echo ""

# Vérifier qu'on est sur un système NixOS installé
if [ ! -f /etc/NIXOS ]; then
    echo "❌ Ce script doit être exécuté sur un système NixOS installé"
    exit 1
fi

HOSTNAME=$(hostname)
echo "📍 Hostname: $HOSTNAME"
echo ""

# 1. Afficher la génération actuelle
echo "🔢 Génération actuelle:"
nixos-version
echo ""

# 2. Calculer le hash de la closure du système
echo "🔐 Hash de la closure système:"
SYSTEM_PATH=$(readlink -f /run/current-system)
echo "  Path: $SYSTEM_PATH"
CLOSURE_HASH=$(nix-store --query --hash "$SYSTEM_PATH")
echo "  Hash: $CLOSURE_HASH"
echo ""

# 3. Lister les chemins de la closure
echo "📦 Taille de la closure:"
nix path-info -rsSh "$SYSTEM_PATH" | tail -n1
echo ""

# 4. Vérifier l'utilisation du cache
echo "🗄️  Statistiques du cache binaire:"
if grep -q "magnolia:5000" /etc/nixos/hosts/"$HOSTNAME"/configuration.nix 2>/dev/null || \
   grep -q "magnolia:5000" /etc/nixos/modules/base.nix 2>/dev/null; then
    echo "  ✅ Cache Magnolia configuré"
    if curl -s --connect-timeout 2 http://magnolia:5000/nix-cache-info > /dev/null; then
        echo "  ✅ Cache Magnolia accessible"
    else
        echo "  ⚠️  Cache Magnolia non accessible"
    fi
else
    echo "  ⚠️  Cache Magnolia non configuré"
fi
echo ""

# 5. Test de rebuild (doit être instantané si cache fonctionne)
echo "🔄 Test de rebuild (avec cache):"
echo "  Lancement de: nixos-rebuild dry-build --flake /etc/nixos#$HOSTNAME"
START_TIME=$(date +%s)

if nixos-rebuild dry-build --flake /etc/nixos#"$HOSTNAME" 2>&1 | tee /tmp/rebuild-test.log; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo ""
    echo "  ✅ Dry-build réussi en ${DURATION}s"

    # Analyser les logs pour voir si on a utilisé le cache
    if grep -q "copying path.*from 'http://magnolia:5000'" /tmp/rebuild-test.log; then
        echo "  ✅ Packages téléchargés depuis le cache"
    elif grep -q "building.*drv" /tmp/rebuild-test.log; then
        echo "  ⚠️  Certains packages ont été compilés (cache incomplet)"
    else
        echo "  ✅ Tous les packages déjà en cache local"
    fi
else
    echo "  ❌ Dry-build échoué"
fi
echo ""

# 6. Sauvegarder les informations pour comparaison
OUTPUT_FILE="/tmp/reproducibility-test-$(date +%Y%m%d-%H%M%S).txt"
cat > "$OUTPUT_FILE" <<EOF
Hostname: $HOSTNAME
Date: $(date -Iseconds)
NixOS Version: $(nixos-version)
System Path: $SYSTEM_PATH
Closure Hash: $CLOSURE_HASH
Closure Size: $(nix path-info -rsSh "$SYSTEM_PATH" | tail -n1)
Flake Lock: $(cat /etc/nixos/flake.lock | sha256sum | cut -d' ' -f1)
EOF

echo "📄 Rapport sauvegardé: $OUTPUT_FILE"
echo ""
echo "💡 Pour comparer deux installations:"
echo "   1. Exécutez ce script sur VM1 et VM2"
echo "   2. Comparez les fichiers /tmp/reproducibility-test-*.txt"
echo "   3. Les 'Closure Hash' doivent être identiques"
echo ""
echo "=== Fin du test ==="
