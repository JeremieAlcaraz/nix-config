########################################################
#                 MEDIA DOWNLOAD                       #
# Fonctions pour le téléchargement de médias          #
########################################################

# Télécharger une partie d'une vidéo YouTube en audio MP3
# Usage: dl_part "URL?t=START" "URL?t=END" "nom-du-fichier"
dl_part() {
    # Récupère le temps après "t="
    start="${1##*t=}"
    end="${2##*t=}"
    # Nettoie l'URL pour garder la base
    url="${1%\?*}"
    # Nom du fichier de sortie
    output_name="${3:-download}"

    echo "Téléchargement AUDIO optimisé de $start à $end..."
    echo "Fichier de sortie : ~/Downloads/$output_name.mp3"
    # -f bestaudio : Télécharge directement l'audio (évite le bug ffmpeg code 183)
    yt-dlp --download-sections "*$start-$end" -f bestaudio -x --audio-format mp3 -o "$HOME/Downloads/$output_name.%(ext)s" "$url"
}
