# Learnix — carnet de bord

Bienvenue dans ce petit terrain d'expérimentation pour apprendre Nix avec les flakes. Ce dossier t'accompagnera pas à pas.

## 1. Pré-requis rapides
- Installe Nix (si ce n'est pas déjà fait) avec la méthode recommandée par `https://nixos.org/download.html`.
- Active les flakes (sur macOS avec la config `~/.config/nix/nix.conf` : ajoute `experimental-features = nix-command flakes`).

## 2. Comprendre le flake de base
Le fichier `flake.nix` à la racine définit :
- **inputs** : les dépendances (ici `nixpkgs` et `flake-utils`).
- **outputs** : ce que ton flake rend disponible. Pour chaque plateforme supportée par `flake-utils`, on fournit :
  - `packages.default` → un paquet simple (`hello`) pour vérifier que tout fonctionne.
  - `devShells.default` → un shell de développement contenant `hello` et `nixpkgs-fmt`.

## 3. Premiers pas
1. Mets à jour les inputs :
   ```bash
   nix flake update
   ```
2. Lance le paquet par défaut :
   ```bash
   nix run
   ```
3. Entre dans le shell de dev :
   ```bash
   nix develop
   ```

## 4. Prochaines explorations
- Ajoute un paquet personnalisé dans `packages` (par exemple un script simple).
- Modifie `devShells.default` pour inclure les outils dont tu as besoin.
- Crée un dossier `modules/` pour tester la configuration de modules Nix.
- Note tes découvertes dans `docs/notes.md` pour garder une trace.

## 5. Bonnes pratiques Git
- Utilise la convention **gitmoji** pour les messages de commit (ex. `:sparkles: Ajoute SSH avec clé publique`).
- Grouper les changements cohérents avant de pousser sur la branche distante.

Bon apprentissage !
