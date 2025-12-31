
#!/bin/zsh
# Reçoit "DISPLAY<TAB>REALPATH" ; on n'affiche que DISPLAY et on lit le vrai chemin.

line="$1"
# Le chemin affiché est le même que le vrai chemin (format simple)
REAL="$line"
DISPLAY_PART="$line"

print -- "$DISPLAY_PART"
printf "Créé le: "; mdls -name kMDItemFSCreationDate -raw "$REAL" 2>/dev/null || true
echo; echo "---"

if [[ -d "$REAL" ]]; then
  ls -la "$REAL"
elif file --mime "$REAL" | grep -q "text/"; then
  bat -n --color=always "$REAL"
else
  file -b "$REAL"
fi

