########################################################
#                FILE MANAGEMENT                       #
# Fonctions pour la gestion de fichiers               #
########################################################

# Fonction NNN avec persistance de répertoire
if command -v nnn &> /dev/null; then
    nnn() {
        command nnn "$@"
        if [ -f "${NNN_TMPFILE}" ]; then
            . "${NNN_TMPFILE}"
        fi
    }
fi
