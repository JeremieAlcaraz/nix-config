# Plan de tâches — Marigold Zsh: cache intelligent + `v **<TAB>` (fzf + fd)

## Scope

Mettre en place une complétion fuzzy récursive fiable pour `v` (alias `nvim`) via `fzf` + `fd`, avec un cache intelligent pour réduire la latence, sans casser `fzf-tab`, `television`, ni les performances de startup.

## Success Criteria

1. `v **<TAB>` affiche une liste récursive (flatten) des fichiers du dossier courant.
2. La complétion standard `<TAB>` reste pilotée par `fzf-tab` (pas de régression de comportement).
3. Plus d’erreur de récursion `fzf-tab-complete` pendant l’usage normal.
4. Le coût de génération des candidats baisse sur répétition (cache actif observable).
5. Le startup shell reste stable (pas de régression notable).

## Contraintes techniques (marigold)

- Les modules Zsh sont mappés explicitement dans `home/marigold.nix` (`01..07`, `99`) : privilégier des edits dans les fichiers existants.
- Les fonctions Zsh sont aussi mappées explicitement : si possible, enrichir `modules/dotfiles/zsh/functions/fzf-helpers.zsh` au lieu d’ajouter un nouveau fichier fonction.
- Documentation en français et commandes reproductibles.

## Phases

### P1 — Baseline et garde-fous

- [x] T01 Mesurer le baseline startup/complétion avant changements
      Depends on: -
      Changes: `modules/dotfiles/zsh/scripts/bench-zsh-completion.sh` (nouveau)
      Benefits: disposer d’un point de comparaison objectif avant/après
      Tests: `bash modules/dotfiles/zsh/scripts/bench-zsh-completion.sh`
      Commit: `chore(zsh): add baseline benchmark script for completion performance`

- [x] T02 Ajouter un smoke test shell pour vérifier les composants critiques
      Depends on: T01
      Changes: `modules/dotfiles/zsh/scripts/check-zsh-completion.sh` (nouveau)
      Benefits: détecter rapidement les régressions de bindings/widgets/fonctions
      Tests: `bash modules/dotfiles/zsh/scripts/check-zsh-completion.sh`
      Commit: `test(zsh): add completion smoke checks for marigold`

### P2 — Activer proprement `fzf` completion pour `**<TAB>`

- [x] T03 Charger `completion.zsh` de fzf sans casser l’ordre actuel
      Depends on: T02
      Changes: `modules/dotfiles/zsh/modules/07-fzf.zsh`
      Benefits: activer la mécanique native `**<TAB>` (non couverte par `key-bindings.zsh` seul)
      Tests: `zsh -n modules/dotfiles/zsh/modules/07-fzf.zsh && zsh -ic 'typeset -f _fzf_complete >/dev/null && echo ok'`
      Commit: `feat(zsh): load fzf completion script for recursive trigger`

- [ ] T04 Uniformiser la source de candidats `fd` pour `**<TAB>`
      Depends on: T03
      Changes: `modules/dotfiles/zsh/modules/07-fzf.zsh`
      Benefits: garantir une recherche récursive cohérente avec filtres (`.git`, `.DS_Store`)
      Tests: `zsh -ic 'typeset -f _fzf_compgen_path >/dev/null && _fzf_compgen_path . | head -n 5'`
      Commit: `feat(zsh): configure fd-based fzf compgen for recursive completion`

### P3 — Cache intelligent des candidats

- [ ] T05 Implémenter un moteur de candidats intelligent (git-first puis fd)
      Depends on: T04
      Changes: `modules/dotfiles/zsh/functions/fzf-helpers.zsh`
      Benefits: accélérer les gros repos en exploitant l’index git quand disponible
      Tests: `zsh -ic 'typeset -f _v_candidates_source >/dev/null && _v_candidates_source | head -n 10'`
      Commit: `feat(zsh): add smart candidate source using git index fallback to fd`

- [ ] T06 Ajouter un cache mémoire TTL par contexte (cwd/repo)
      Depends on: T05
      Changes: `modules/dotfiles/zsh/functions/fzf-helpers.zsh`
      Benefits: éviter les rescans coûteux lors des Tabs successifs
      Tests: `zsh -ic 'typeset -f _v_candidates_cached >/dev/null && _v_candidates_cached >/dev/null && _v_candidates_cached >/dev/null'`
      Commit: `feat(zsh): add in-memory ttl cache for completion candidates`

- [ ] T07 Ajouter invalidation légère et toggles de debug/cache
      Depends on: T06
      Changes: `modules/dotfiles/zsh/functions/fzf-helpers.zsh`, `modules/dotfiles/zsh/modules/01-options.zsh`
      Benefits: comportement prévisible (debuggable) + rollback rapide en cas de souci
      Tests: `zsh -ic 'echo ${ZSH_V_FZF_CACHE_TTL:-unset}; typeset -p _V_FZF_CACHE 2>/dev/null || true'`
      Commit: `feat(zsh): add cache controls and invalidation hooks`

### P4 — Intégration `v`/`nvim` et non-régression `fzf-tab`

- [ ] T08 Brancher le cache sur la complétion `v **<TAB>` / `nvim **<TAB>`
      Depends on: T07
      Changes: `modules/dotfiles/zsh/modules/04-completion.zsh`, `modules/dotfiles/zsh/modules/07-fzf.zsh`, `modules/dotfiles/zsh/modules/05-aliases.zsh`
      Benefits: UX cible atteinte avec alias `v` et comportement cohérent sur `nvim`
      Tests: `zsh -n modules/dotfiles/zsh/modules/04-completion.zsh && zsh -n modules/dotfiles/zsh/modules/07-fzf.zsh`
      Commit: `feat(zsh): wire smart cached candidates to nvim fzf completion`

- [ ] T09 Vérifier explicitement que `<TAB>` standard reste `fzf-tab`
      Depends on: T08
      Changes: `modules/dotfiles/zsh/scripts/check-zsh-completion.sh`
      Benefits: éviter de reintroduire les erreurs de récursion et préserver les habitudes
      Tests: `bash modules/dotfiles/zsh/scripts/check-zsh-completion.sh && zsh -ic 'bindkey -M emacs "^I"'`
      Commit: `test(zsh): assert default tab remains bound to fzf-tab`

### P5 — Validation finale et documentation

- [ ] T10 Documenter l’usage et les variables de tuning (FR)
      Depends on: T09
      Changes: `docs/MARIGOLD-ZSH-FZF-COMPLETION.md`
      Benefits: maintenance et onboarding simplifiés
      Tests: `rg -n "v \*\*<TAB>|ZSH_V_FZF_CACHE|fzf-tab" docs/MARIGOLD-ZSH-FZF-COMPLETION.md`
      Commit: `docs(marigold): document fzf completion and smart cache workflow`

- [ ] T11 Valider la config marigold et procédure d’activation
      Depends on: T10
      Changes: `tasks-plan.md` (mise à jour statuts/checklist), éventuellement `docs/DEPLOYMENT_WORKFLOWS.md`
      Benefits: clôture propre avec runbook de vérification post-switch
      Tests: `darwin-rebuild build --flake .#marigold`
      Commit: `chore(marigold): finalize validation checklist for zsh completion rollout`

## Recette de validation interactive (à exécuter à chaque jalon clé)

1. Ouvrir un nouveau shell: `exec zsh`
2. Vérifier `Tab` normal: `cd <TAB>` puis `git checkout <TAB>`
3. Vérifier trigger cible: `v **<TAB>` puis `nvim **<TAB>`
4. Vérifier absence d’erreurs: aucune ligne `fzf-tab-complete: ... recursion ...`
5. Vérifier prompt: pas de warnings Starship anormaux

## Politique d’exécution

- Une tâche = un commit.
- Ne pas passer à la tâche suivante sans exécuter les tests de la tâche courante.
- En cas de changement de scope, mettre à jour dépendances et IDs de tâches dans ce fichier.
