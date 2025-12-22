#!/bin/bash

# Script pour télécharger un dossier spécifique depuis GitHub
# Usage: ./github-folder-downloader.sh

set -e # Arrête le script en cas d'erreur

# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages colorés
print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_info() {
  echo -e "${YELLOW}ℹ $1${NC}"
}

# Fonction pour nettoyer en cas d'erreur
cleanup() {
  if [ -d "$temp_dir" ]; then
    print_info "Nettoyage en cours..."
    rm -rf "$temp_dir"
  fi
}

# Trap pour nettoyer en cas d'interruption
trap cleanup EXIT

echo "🚀 GitHub Folder Downloader"
echo "=========================="
echo ""

# Demander l'URL
read -p "Entrez l'URL GitHub (ex: https://github.com/user/repo/tree/main/folder): " url

# Vérifier que l'URL n'est pas vide
if [ -z "$url" ]; then
  print_error "URL non fournie"
  exit 1
fi

# Vérifier le format de l'URL
if [[ ! "$url" =~ ^https://github\.com/[^/]+/[^/]+/tree/[^/]+/ ]]; then
  print_error "Format d'URL invalide. Utilisez le format: https://github.com/user/repo/tree/branch/path"
  exit 1
fi

# Parser l'URL
# Exemple: https://github.com/Sou1lah/Dotfiles/tree/main/.config/nvim
repo_url=$(echo "$url" | sed 's|/tree/.*||')            # https://github.com/Sou1lah/Dotfiles
branch_and_path=$(echo "$url" | sed 's|.*/tree/||')     # main/.config/nvim
branch=$(echo "$branch_and_path" | cut -d'/' -f1)       # main
folder_path=$(echo "$branch_and_path" | cut -d'/' -f2-) # .config/nvim

# Extraire le nom du dossier pour le nom final
folder_name=$(basename "$folder_path")

print_info "Repository: $repo_url"
print_info "Branch: $branch"
print_info "Dossier: $folder_path"
print_info "Nom de sortie: $folder_name"

# Créer un dossier temporaire
temp_dir=$(mktemp -d)
print_info "Dossier temporaire: $temp_dir"

# Aller dans le dossier temporaire
cd "$temp_dir"

print_info "Initialisation du repository local..."
git init --quiet

print_info "Ajout du repository distant..."
git remote add origin "$repo_url"

print_info "Configuration du sparse checkout..."
git sparse-checkout init --cone
git sparse-checkout set "$folder_path"

print_info "Téléchargement des fichiers..."
git pull origin "$branch" --quiet

# Vérifier que le dossier existe
if [ ! -d "$folder_path" ]; then
  print_error "Le dossier '$folder_path' n'existe pas dans le repository"
  exit 1
fi

# Retourner au dossier original
cd - >/dev/null

# Copier le dossier vers le répertoire courant
if [ -d "$folder_name" ]; then
  print_info "Le dossier '$folder_name' existe déjà. Remplacement..."
  rm -rf "$folder_name"
fi

cp -r "$temp_dir/$folder_path" "$folder_name"

# Nettoyer le dossier temporaire
rm -rf "$temp_dir"

print_success "Téléchargement terminé !"
print_success "Dossier créé: $(pwd)/$folder_name"

# Afficher le contenu
echo ""
print_info "Contenu téléchargé:"
ls -la "$folder_name" | head -10
if [ $(ls -1 "$folder_name" | wc -l) -gt 10 ]; then
  echo "... ($(ls -1 "$folder_name" | wc -l) fichiers au total)"
fi
