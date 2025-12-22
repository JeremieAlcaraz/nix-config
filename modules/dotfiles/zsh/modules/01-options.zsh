

########################################################
#                 ZSH OPTIONS                          #
# Configuration du comportement de zsh                #
########################################################

# Évite les erreurs "no matches found" pour les patterns vides
setopt no_nomatch
# === NAVIGATION ===
setopt AUTO_CD                    # cd automatique sans taper "cd"

# === SHELL INTERACTIF ===
setopt INTERACTIVE_COMMENTS       # Permet commentaires # en ligne de commande


# === CORRECTION INTELLIGENTE ===
setopt CORRECT                   # Corrige commandes mal tapées
setopt CORRECT_ALL             # Corrige aussi les arguments (optionnel)

# === HISTORIQUE ===
setopt HIST_FCNTL_LOCK           # Verrouillage sécurisé du fichier historique
setopt HIST_IGNORE_ALL_DUPS      # Ignore tous les doublons dans historique
setopt SHARE_HISTORY             # Partage historique entre sessions zsh

# === DÉSACTIVATION D'OPTIONS ===
unsetopt AUTO_REMOVE_SLASH       # Garde le slash final des dossiers
unsetopt HIST_EXPIRE_DUPS_FIRST  # N'expire pas les doublons en premier
