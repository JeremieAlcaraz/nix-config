# AeroSpace - crash au demarrage (macOS)

## Symptomes
- AeroSpace ne reste pas lance (process qui meurt immediatement).
- Les spaces et le tiling ne fonctionnent plus.
- Prompt d'accessibilite accepte, mais l'app quitte quand meme.

## Diagnostic rapide
- Logs AeroSpace montrent un exit juste apres la demande TCC.
- Dans la base TCC systeme, l'entree Accessibility pour `bobko.aerospace` est en refus.

Commandes utiles :

```bash
/usr/bin/log show --last 2m --predicate 'process == "AeroSpace"' --style compact | tail -n 80
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "select service,client,auth_value,auth_reason from access where service='kTCCServiceAccessibility' and client='bobko.aerospace';"
```

## Cause probable
- Entree TCC systeme en refus (auth_value=0) pour `bobko.aerospace`, ce qui bloque l'accessibilite.

## Correctif (celui utilise)
1) Reset TCC pour AeroSpace et relancer l'app :

```bash
sudo tccutil reset Accessibility bobko.aerospace
open /Applications/AeroSpace.app
```

2) Re-autoriser AeroSpace dans :
- Reglages Systeme > Confidentialite et securite > Accessibilite
- Ajouter a la fois l'app et le binaire si besoin :
  - `/Applications/AeroSpace.app`
  - `/Applications/AeroSpace.app/Contents/MacOS/AeroSpace`

3) Si le reset ne suffit pas, verifier que le terminal a "Acces complet au disque"
   puis relancer le reset TCC.

## Prevention
- Eviter de refuser le prompt Accessibilite lors de mises a jour d'AeroSpace.
- Garder AeroSpace a jour (via Homebrew cask) pour eviter des bugs TCC.

## Notes
- Sketchybar peut etre arrete pour isoler le probleme, puis relance ensuite :

```bash
brew services stop sketchybar
brew services start sketchybar
```
