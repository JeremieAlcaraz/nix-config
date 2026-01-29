#!/usr/bin/env bash
set -euo pipefail

# Script pour appliquer la solution permanente au bug AeroSpace
# Ce script automatise les étapes décrites dans docs/AEROSPACE-FIX.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Fix AeroSpace - Solution Permanente"
echo "======================================"
echo ""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Vérifier qu'on est dans le bon répertoire
if [[ ! -f "$REPO_ROOT/flake.nix" ]]; then
    error "Ce script doit être exécuté depuis le dépôt nix-config"
    exit 1
fi

echo "Étape 1/5 : Nettoyage de l'installation actuelle"
echo "================================================"
echo ""

# Arrêter AeroSpace
info "Arrêt d'AeroSpace..."
if pgrep -x "AeroSpace" > /dev/null; then
    pkill AeroSpace
    sleep 2
    success "AeroSpace arrêté"
else
    info "AeroSpace n'est pas en cours d'exécution"
fi

# Désinstaller la version beta si elle existe
info "Désinstallation de la version beta..."
if brew list --cask aerospace &>/dev/null; then
    brew uninstall --cask aerospace || true
    success "Version beta désinstallée"
else
    info "Aucune version beta installée"
fi

# Nettoyer les permissions TCC
info "Nettoyage des permissions TCC..."
echo "⚠️  Un mot de passe sudo sera demandé pour nettoyer les permissions"
sudo tccutil reset Accessibility bobko.aerospace 2>/dev/null || true
sudo tccutil reset SystemPolicyAllFiles bobko.aerospace 2>/dev/null || true
success "Permissions TCC nettoyées"

echo ""
echo "Étape 2/5 : Application de la configuration Nix"
echo "==============================================="
echo ""

info "Rebuild nix-darwin avec la nouvelle configuration..."
cd "$REPO_ROOT"
darwin-rebuild switch --flake .#marigold

if [[ $? -eq 0 ]]; then
    success "Configuration appliquée avec succès"
else
    error "Erreur lors de l'application de la configuration"
    exit 1
fi

echo ""
echo "Étape 3/5 : Configuration des permissions"
echo "========================================="
echo ""

warning "IMPORTANT : Configuration manuelle requise"
echo ""
echo "Ouvre maintenant :"
echo "  1. Réglages Système → Confidentialité et sécurité → Accessibilité"
echo "  2. Clique sur le cadenas pour déverrouiller"
echo "  3. Clique sur '+' et ajoute : /Applications/AeroSpace.app"
echo "  4. Coche la case pour autoriser AeroSpace"
echo ""
read -p "Appuie sur Entrée quand c'est fait..."

success "Permissions configurées"

echo ""
echo "Étape 4/5 : Vérification du LaunchAgent"
echo "======================================="
echo ""

# Attendre que le LaunchAgent soit chargé
sleep 2

info "Vérification du LaunchAgent..."
if launchctl list | grep -q "com.nikitabobko.aerospace"; then
    success "LaunchAgent chargé et actif"
else
    warning "Le LaunchAgent n'est pas encore chargé"
    info "Chargement manuel du LaunchAgent..."

    PLIST_PATH="$HOME/Library/LaunchAgents/com.nikitabobko.aerospace.plist"
    if [[ -f "$PLIST_PATH" ]]; then
        launchctl load "$PLIST_PATH"
        sleep 2
        success "LaunchAgent chargé manuellement"
    else
        error "Fichier plist introuvable à : $PLIST_PATH"
        error "Le rebuild home-manager n'a peut-être pas créé le LaunchAgent"
    fi
fi

# Vérifier qu'AeroSpace est lancé
sleep 3
if pgrep -x "AeroSpace" > /dev/null; then
    success "AeroSpace est en cours d'exécution"
else
    warning "AeroSpace n'est pas encore démarré"
    info "Tentative de démarrage manuel..."
    open /Applications/AeroSpace.app
    sleep 3
fi

echo ""
echo "Étape 5/5 : Nettoyage des login items manuels"
echo "============================================="
echo ""

warning "IMPORTANT : Nettoyage manuel requis"
echo ""
echo "Ouvre maintenant :"
echo "  1. Réglages Système → Général → Éléments de connexion"
echo "  2. Retire 'AeroSpace' de la liste (s'il y est)"
echo "  3. Le LaunchAgent gère maintenant le démarrage automatique"
echo ""
read -p "Appuie sur Entrée quand c'est fait..."

success "Login items nettoyés"

echo ""
echo "======================================"
echo "🎉 Configuration terminée !"
echo "======================================"
echo ""

info "Vérifications finales..."
echo ""

# Vérifier la version installée
AEROSPACE_VERSION=$(aerospace --version 2>/dev/null || echo "Erreur")
echo "Version d'AeroSpace : $AEROSPACE_VERSION"

# Vérifier le processus
if pgrep -x "AeroSpace" > /dev/null; then
    echo -e "${GREEN}✓${NC} AeroSpace est en cours d'exécution"
else
    echo -e "${YELLOW}⚠${NC} AeroSpace n'est pas en cours d'exécution"
fi

# Vérifier le LaunchAgent
if launchctl list | grep -q "com.nikitabobko.aerospace"; then
    echo -e "${GREEN}✓${NC} LaunchAgent est actif"
else
    echo -e "${RED}✗${NC} LaunchAgent n'est pas actif"
fi

# Vérifier les logs
LOG_DIR="$HOME/Library/Logs/AeroSpace"
if [[ -d "$LOG_DIR" ]]; then
    echo -e "${GREEN}✓${NC} Dossier de logs créé : $LOG_DIR"
else
    echo -e "${YELLOW}⚠${NC} Dossier de logs introuvable"
fi

echo ""
info "Pour vérifier que tout fonctionne :"
echo "  1. Teste le redémarrage automatique : pkill AeroSpace"
echo "  2. Attends 2-3 secondes et vérifie que l'app redémarre"
echo "  3. Redémarre ton Mac pour confirmer que tout fonctionne au boot"
echo ""

info "Logs disponibles :"
echo "  - stdout : tail -f ~/Library/Logs/AeroSpace/stdout.log"
echo "  - stderr : tail -f ~/Library/Logs/AeroSpace/stderr.log"
echo ""

info "Documentation complète :"
echo "  $REPO_ROOT/docs/AEROSPACE-FIX.md"
echo ""

success "Terminé ! 🎉"
