# AeroSpace - Solution Permanente au Bug de Redémarrage

## Problème Identifié

À chaque redémarrage de macOS, AeroSpace ne se relance pas correctement et nécessite un reset manuel des permissions TCC (Transparency, Consent, and Control).

### Causes Racines

1. **Conflit de versions** : La configuration Nix spécifie `aerospace@0.19.2` (stable) mais `0.20.2-Beta` était installée
2. **Signature incomplète** : L'app n'a pas de `TeamIdentifier` (développeur certifié Apple), ce qui fait que macOS révoque les permissions à chaque boot
3. **Gestion manuelle** : Le login item macOS n'est pas déclaratif et n'est pas robuste aux problèmes de permissions

### Diagnostic Effectué

```bash
# Vérifier la signature de l'app
codesign -dv /Applications/AeroSpace.app
# Résultat : TeamIdentifier=not set ❌

# Vérifier l'état TCC
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "select service,client,auth_value from access where client='bobko.aerospace';"
# Les permissions sont révoquées après chaque redémarrage

# Vérifier les logs
/usr/bin/log show --last 2m --predicate 'process == "AeroSpace"' --style compact
# L'app se termine normalement mais ne redémarre pas
```

## Solution Permanente Implémentée

### 1. LaunchAgent Déclaratif (via home-manager)

Un LaunchAgent a été configuré dans `home/aerospace.nix` qui :
- Démarre automatiquement AeroSpace au login
- **Redémarre l'app automatiquement** si elle quitte ou crash
- Enregistre les logs pour debug
- Est géré de manière déclarative (survit aux mises à jour)

Configuration :
```nix
launchd.agents.aerospace = {
  enable = true;
  config = {
    ProgramArguments = [ "/Applications/AeroSpace.app/Contents/MacOS/AeroSpace" ];
    Label = "com.nikitabobko.aerospace";
    RunAtLoad = true;
    KeepAlive = {
      SuccessfulExit = false;  # Redémarre si l'app quitte
      Crashed = true;          # Redémarre si crash
    };
    ProcessType = "Interactive";
    StandardErrorPath = "~/Library/Logs/AeroSpace/stderr.log";
    StandardOutPath = "~/Library/Logs/AeroSpace/stdout.log";
  };
};
```

### 2. Version Stable

La configuration utilise `aerospace@0.19.2` (dernière version stable) au lieu de la beta.

## Procédure d'Application

### Étape 1 : Nettoyer l'installation actuelle

```bash
# Arrêter AeroSpace
pkill AeroSpace

# Désinstaller la version beta
brew uninstall aerospace

# Nettoyer les permissions TCC
sudo tccutil reset Accessibility bobko.aerospace
sudo tccutil reset SystemPolicyAllFiles bobko.aerospace
```

### Étape 2 : Appliquer la nouvelle configuration

```bash
cd ~/Development/_programmation/_production/_services/nix-config

# Rebuild nix-darwin (installe aerospace@0.19.2)
darwin-rebuild switch --flake .#marigold
```

### Étape 3 : Autoriser les permissions

1. Ouvrir **Réglages Système** → **Confidentialité et sécurité** → **Accessibilité**
2. Ajouter `/Applications/AeroSpace.app` (cliquer sur le `+`)
3. Cocher la case pour autoriser AeroSpace

### Étape 4 : Charger le LaunchAgent

Le LaunchAgent est automatiquement chargé par home-manager. Vérifie qu'il est actif :

```bash
# Vérifier que le LaunchAgent est chargé
launchctl list | grep aerospace

# Démarrer manuellement si besoin
launchctl load ~/Library/LaunchAgents/com.nikitabobko.aerospace.plist

# AeroSpace devrait démarrer automatiquement
```

### Étape 5 : Retirer le login item manuel

1. Ouvrir **Réglages Système** → **Général** → **Éléments de connexion**
2. Retirer **AeroSpace** de la liste (il est maintenant géré par le LaunchAgent)

## Vérification

### Tester le redémarrage automatique

```bash
# Tuer AeroSpace pour voir s'il redémarre
pkill AeroSpace

# Attendre 2-3 secondes, puis vérifier
ps aux | grep AeroSpace
# L'app devrait être relancée automatiquement par le LaunchAgent
```

### Vérifier les logs

```bash
# Logs du LaunchAgent
tail -f ~/Library/Logs/AeroSpace/stdout.log
tail -f ~/Library/Logs/AeroSpace/stderr.log

# Logs système
log show --last 5m --predicate 'process == "AeroSpace"' --style compact
```

### Vérifier les permissions TCC

```bash
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "select service,client,auth_value,auth_reason from access where client='bobko.aerospace';"
```

Expected output :
```
kTCCServiceAccessibility|bobko.aerospace|2|4
```
(`auth_value=2` = autorisé)

## Avantages de cette Solution

1. **Déclaratif** : Tout est géré dans la config Nix, pas de setup manuel
2. **Robuste** : Le LaunchAgent redémarre automatiquement l'app en cas de problème
3. **Reproductible** : Fonctionne sur n'importe quelle machine avec la même config
4. **Logs** : Debug facile avec les logs centralisés
5. **Version stable** : Pas de problèmes de signature avec les versions beta

## Dépannage

### Si AeroSpace ne démarre toujours pas après un reboot

1. Vérifier que le LaunchAgent est chargé :
   ```bash
   launchctl list | grep aerospace
   ```

2. Vérifier les permissions dans Réglages Système

3. Vérifier les logs :
   ```bash
   tail -50 ~/Library/Logs/AeroSpace/stderr.log
   ```

4. Si nécessaire, recharger le LaunchAgent :
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.nikitabobko.aerospace.plist
   launchctl load ~/Library/LaunchAgents/com.nikitabobko.aerospace.plist
   ```

### Si les permissions sont révoquées à chaque boot

C'est normalement résolu par la version stable et le LaunchAgent. Si le problème persiste :

1. Vérifier la signature :
   ```bash
   codesign -dv /Applications/AeroSpace.app
   ```

2. S'assurer que Terminal a "Accès complet au disque" dans les réglages
3. Refaire le reset TCC et reconfigurer les permissions

## Notes

- Le LaunchAgent démarre AeroSpace au login ET le relance s'il quitte
- Les logs sont dans `~/Library/Logs/AeroSpace/`
- La configuration est gérée de manière déclarative via home-manager
- Plus besoin de faire le reset TCC manuel à chaque redémarrage !
