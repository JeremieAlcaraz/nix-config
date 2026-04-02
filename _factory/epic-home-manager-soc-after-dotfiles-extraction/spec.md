# [EPIC] Redéfinir le scope Home Manager après extraction des dotfiles

## Contexte
La gestion de symlinks de dotfiles par Home Manager ajoute de la complexité et de la friction pour les outils qui attendent des chemins directs. Une migration progressive vers Dotbot est envisagée dans le repo dotfiles.

## Objectif
Définir clairement la séparation des responsabilités (SoC) de Home Manager après extraction des dotfiles, puis nettoyer la configuration HM pour rester minimaliste et utile.

## Non-objectifs
- Réécrire toute l'infra Nix en une passe.
- Migrer brutalement tous les packages sans validation.

## Résultat attendu
- Contrat de scope HM documenté et accepté.
- Déclarations HM dotfiles retirées progressivement et proprement.
- Garde-fous pour éviter une réintroduction accidentelle.
