#!/bin/zsh
# fd version — sort un "DISPLAY<TAB>REALPATH" pour que la liste soit courte.

set -eu

DIRS_FILE=${TV_DIRS_FILE:-$HOME/.config/television/recent-dirs.txt}
EXC_FILE=${TV_EXCLUDE_FILE:-$HOME/.config/television/recent-exclude.txt}

# OUTPUT_FORMAT: mapping|display|real (auto: display si tty, sinon mapping)
OUTPUT_FORMAT=${TV_OUTPUT_FORMAT:-}
DAYS=${TV_DAYS:-7}
MODE=${TV_ATTR:-modified}   # modified|created|both
DO_SORT=${TV_SORT:-1}       # 1 = trier du plus récent au plus ancien

if [[ -z "$OUTPUT_FORMAT" ]]; then
  if [[ -t 1 ]]; then
    OUTPUT_FORMAT=display
  else
    OUTPUT_FORMAT=mapping
  fi
fi

read_dirs() {
  local d; local -a arr=()
  while IFS= read -r d || [[ -n "$d" ]]; do
    [[ -z "$d" || "$d" == \#* ]] && continue
    d=${d/#~/$HOME}; d=${d//\$HOME/$HOME}
    arr+=("$d")
  done < "$DIRS_FILE"
  printf '%s\n' "${arr[@]}"
}

apply_excludes() {
  if [[ -s "$EXC_FILE" ]]; then grep -v -f "$EXC_FILE" || true; else cat; fi
}

shorten() {
  # $1 = chemin réel -> renvoie DISPLAY court (max 60 caractères)
  local p="$1" disp ptilde rel="" base="" first="" tail=""
  ptilde="${p/#$HOME/~}"

  if [[ "$p" == "$HOME" ]]; then
    printf '%s\n' "~"
    return
  fi

  if [[ "$p" == "$HOME/"* ]]; then
    rel="${p#$HOME/}"
    base="${p##*/}"

    if [[ "$rel" == */* ]]; then
      first="${rel%%/*}"
      tail="${rel#*/}"
    else
      first="$rel"
      tail=""
    fi

    if [[ -z "$tail" ]]; then
      disp="~/${rel}"
    elif [[ "$tail" == "$base" ]]; then
      disp="~/${first}/${base}"
    else
      disp="~/${first}/.../${base}"
    fi

    printf '%s\n' "$disp"
    return
  fi

  # Pour les chemins hors HOME, conserver l'ancien traitement
  if [[ ${#ptilde} -gt 60 ]]; then
    disp="${ptilde:0:57}..."
  else
    disp="$ptilde"
  fi
  printf '%s\n' "$disp"
}

dirs=($(read_dirs))
(( ${#dirs} == 0 )) && { echo "[recent-files] Aucun dossier valide dans $DIRS_FILE" >&2; exit 0; }

collect_modified() { fd --hidden --follow --type f --changed-within "${DAYS}d" . "${dirs[@]}" 2>/dev/null }
collect_created() {
  local cutoff=$(( $(date +%s) - DAYS*24*3600 ))
  fd --hidden --follow --type f . "${dirs[@]}" 2>/dev/null | while IFS= read -r p; do
    b=$(stat -f %B "$p" 2>/dev/null || echo 0); (( b>0 && b>=cutoff )) && printf '%s\n' "$p"
  done
}
collect_both() { { collect_modified; collect_created; } | sort -u }

case "$MODE" in
  modified) out=$(collect_modified) ;;
  created)  out=$(collect_created) ;;
  both)     out=$(collect_both) ;;
  *)        out=$(collect_modified) ;;
esac

# tri par mtime décroissant si demandé
if [[ -n "${out:-}" && "$DO_SORT" = 1 ]]; then
  out=$(printf '%s\n' "$out" | xargs -I{} stat -f "%m %N" {} 2>/dev/null | sort -nr | cut -d' ' -f2-)
fi

# exclusions puis format "DISPLAY\tREALPATH" attendu par Television
[[ -z "${out:-}" ]] && exit 0

printf '%s\n' "$out" \
| apply_excludes \
| while IFS= read -r real; do
    [[ -z "$real" ]] && continue
    disp=$(shorten "$real")
    case "$OUTPUT_FORMAT" in
      display) printf '%s\n' "$disp" ;;
      real)    printf '%s\n' "$real" ;;
      *)       printf '%s\t%s\n' "$disp" "$real" ;;
    esac
  done
