#!/usr/bin/env bash
set -euo pipefail

# Script de setup pour whitelily (n8n)
# Usage: ./setup-whitelily.sh
#
# Ce script guide l'utilisateur dans la configuration des secrets
# et le déploiement initial de whitelily

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

error() {
    echo -e "${RED}❌ ERREUR: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

step() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}▶ $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

prompt() {
    echo -e "${YELLOW}❓ $1${NC}"
}

# Vérifier qu'on est dans le bon répertoire
if [[ ! -f "flake.nix" ]]; then
    error "Ce script doit être exécuté depuis la racine du repo nix-config"
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                    ║${NC}"
echo -e "${CYAN}║     🤍 Setup Whitelily (n8n automation)          ║${NC}"
echo -e "${CYAN}║                                                    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# ========================================
# Étape 1 : Vérifications préalables
# ========================================
step "Étape 1/5 : Vérifications préalables"

# Vérifier les outils nécessaires
for tool in sops age openssl mkpasswd; do
    if ! command -v "$tool" &> /dev/null; then
        error "L'outil '$tool' n'est pas installé. Installez-le avec: brew install $tool"
    fi
done
info "Tous les outils nécessaires sont installés"

# Vérifier la clé age
AGE_KEY_PATH="$HOME/.config/sops/age/nixos-shared-key.txt"
if [[ ! -f "$AGE_KEY_PATH" ]]; then
    error "Clé age non trouvée dans: $AGE_KEY_PATH"
fi
info "Clé age trouvée"

# Vérifier que le fichier example existe
if [[ ! -f "secrets/whitelily.yaml.example" ]]; then
    error "Le fichier secrets/whitelily.yaml.example n'existe pas"
fi

echo ""

# ========================================
# Étape 2 : Configuration Cloudflare
# ========================================
step "Étape 2/5 : Configuration Cloudflare Tunnel"

warning "Avant de continuer, vous DEVEZ créer un Cloudflare Tunnel"
echo ""
echo "Instructions :"
echo "1. Aller sur https://one.dash.cloudflare.com/"
echo "2. Navigation : Zero Trust → Access → Tunnels"
echo "3. Créer un tunnel nommé : n8n-whitelily"
echo "4. Configurer la route publique :"
echo "   - Subdomain: n8n (ou autre)"
echo "   - Domain: votre-domaine.com"
echo "   - Service: http://localhost:80"
echo "5. Récupérer le JSON des credentials"
echo ""

prompt "Avez-vous créé le tunnel et récupéré les credentials JSON ? (oui/non)"
read -r tunnel_ready
if [[ "$tunnel_ready" != "oui" ]]; then
    error "Créez d'abord le Cloudflare Tunnel puis relancez ce script"
fi

prompt "Quel est votre domaine complet pour n8n ? (ex: n8n.jeremiealcaraz.com)"
read -r DOMAIN

if [[ -z "$DOMAIN" ]]; then
    error "Le domaine ne peut pas être vide"
fi

info "Domaine configuré : $DOMAIN"

echo ""

# ========================================
# Étape 3 : Génération des secrets
# ========================================
step "Étape 3/5 : Génération des secrets"

info "Génération automatique des secrets..."

# Générer les secrets
N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
N8N_BASIC_PASS=$(openssl rand -base64 24)
DB_PASSWORD=$(openssl rand -base64 32)

info "Secrets générés avec succès"

echo ""
warning "⚠️  IMPORTANT : Clé de chiffrement n8n"
echo ""
echo "Cette clé chiffre TOUTES vos credentials n8n."
echo "Si vous la perdez, vous perdez TOUTES vos credentials !"
echo ""
echo -e "${YELLOW}N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}${NC}"
echo ""
prompt "Sauvegardez cette clé dans 1Password/Bitwarden. Tapez 'ok' une fois fait :"
read -r saved
if [[ "$saved" != "ok" ]]; then
    error "Sauvegardez d'abord la clé avant de continuer"
fi

info "Clé sauvegardée ✓"

echo ""
prompt "Choisissez un nom d'utilisateur pour n8n (par défaut: admin):"
read -r N8N_USER
N8N_USER="${N8N_USER:-admin}"

echo ""
info "Génération du hash du mot de passe pour l'utilisateur 'jeremie'..."
prompt "Entrez le mot de passe pour l'utilisateur jeremie (SSH) :"
JEREMIE_HASH=$(mkpasswd -m sha-512)

echo ""
prompt "Collez ici le JSON complet des credentials Cloudflare :"
echo "(Format: {\"AccountTag\": \"...\", \"TunnelSecret\": \"...\", \"TunnelID\": \"...\"})"
CLOUDFLARED_CREDS=""
while IFS= read -r line; do
    [[ -z "$line" ]] && break
    CLOUDFLARED_CREDS+="$line"$'\n'
done

if [[ -z "$CLOUDFLARED_CREDS" ]]; then
    error "Les credentials Cloudflare ne peuvent pas être vides"
fi

# Valider que c'est du JSON
if ! echo "$CLOUDFLARED_CREDS" | jq . &>/dev/null; then
    error "Le JSON des credentials Cloudflare est invalide"
fi

info "Credentials Cloudflare validés"

echo ""

# ========================================
# Étape 4 : Création du fichier secrets
# ========================================
step "Étape 4/5 : Création du fichier secrets"

info "Création du fichier secrets/whitelily.yaml..."

# Créer un fichier temporaire non chiffré
TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE" <<EOF
# Secrets pour whitelily (VM n8n automation)
# Généré automatiquement par setup-whitelily.sh

jeremie-password-hash: ${JEREMIE_HASH}

n8n:
  encryption_key: "${N8N_ENCRYPTION_KEY}"
  basic_user: "${N8N_USER}"
  basic_pass: "${N8N_BASIC_PASS}"
  db_password: "${DB_PASSWORD}"

cloudflared:
  credentials: |
    ${CLOUDFLARED_CREDS}
EOF

# Chiffrer avec sops
info "Chiffrement avec sops..."
SOPS_AGE_KEY_FILE="$AGE_KEY_PATH" sops encrypt "$TEMP_FILE" > secrets/whitelily.yaml

# Nettoyer le fichier temporaire
rm "$TEMP_FILE"

# Vérifier que c'est bien chiffré
if ! grep -q "sops:" secrets/whitelily.yaml; then
    error "Le fichier n'a pas été chiffré correctement"
fi

info "Fichier secrets/whitelily.yaml créé et chiffré avec succès"

echo ""

# ========================================
# Étape 5 : Mise à jour du domaine
# ========================================
step "Étape 5/5 : Mise à jour de la configuration"

info "Mise à jour du domaine dans hosts/whitelily/n8n.nix..."

# Mettre à jour le domaine dans n8n.nix
sed -i.bak "s/domain = \".*\";/domain = \"${DOMAIN}\";/" hosts/whitelily/n8n.nix
rm hosts/whitelily/n8n.nix.bak

info "Domaine mis à jour : ${DOMAIN}"

echo ""

# ========================================
# Résumé et prochaines étapes
# ========================================
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                    ║${NC}"
echo -e "${CYAN}║     ✅ Configuration terminée !                    ║${NC}"
echo -e "${CYAN}║                                                    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

info "Fichiers créés/modifiés :"
echo "  • secrets/whitelily.yaml (chiffré)"
echo "  • hosts/whitelily/n8n.nix (domaine mis à jour)"
echo ""

info "📋 Résumé de la configuration :"
echo "  • Domaine n8n        : ${DOMAIN}"
echo "  • Utilisateur n8n    : ${N8N_USER}"
echo "  • Mot de passe n8n   : ${N8N_BASIC_PASS}"
echo "  • Mot de passe DB    : ${DB_PASSWORD}"
echo ""

warning "⚠️  Sauvegardez ces informations dans un endroit sûr !"
echo ""

info "🚀 Prochaines étapes :"
echo ""
echo "1. Committer et pousser les changements :"
echo "   ${YELLOW}git add secrets/whitelily.yaml hosts/whitelily/n8n.nix${NC}"
echo "   ${YELLOW}git commit -m '🔒 Configure whitelily secrets'${NC}"
echo "   ${YELLOW}git push${NC}"
echo ""
echo "2. Sur la VM whitelily (après installation de NixOS) :"
echo "   ${YELLOW}cd /root/nix-config${NC}"
echo "   ${YELLOW}git pull${NC}"
echo "   ${YELLOW}sudo nixos-rebuild switch --flake .#whitelily${NC}"
echo ""
echo "3. Accéder à n8n :"
echo "   Ouvrir ${CYAN}https://${DOMAIN}${NC}"
echo "   Username : ${N8N_USER}"
echo "   Password : ${N8N_BASIC_PASS}"
echo ""

prompt "Voulez-vous committer et pousser automatiquement ? (oui/non)"
read -r auto_commit
if [[ "$auto_commit" == "oui" ]]; then
    git add secrets/whitelily.yaml hosts/whitelily/n8n.nix
    git commit -m "🔒 Configure whitelily secrets and domain"
    git push
    info "Changements committés et poussés avec succès !"
else
    warning "N'oubliez pas de committer et pousser manuellement"
fi

echo ""
info "Setup terminé ! 🎉"
