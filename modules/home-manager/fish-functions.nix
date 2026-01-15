{ config, pkgs, osConfig, ... }:

{
  # Fish shell functions - Fonctions interactives avancées
  programs.fish = {
    functions = {
      # ═══════════════════════════════════════════════════
      # 🔄 Git Update with Auto-Rebuild Prompt (Magnolia)
      # ═══════════════════════════════════════════════════

      # Remplace l'alias 'gu' par une fonction interactive
      # Sur magnolia, propose automatiquement de rebuild après un pull réussi
      gu = {
        description = "Git fetch + hard reset, puis propose rebuild sur magnolia";
        body = ''
          # Couleurs
          set -l GREEN '\033[0;32m'
          set -l BLUE '\033[0;34m'
          set -l YELLOW '\033[1;33m'
          set -l NC '\033[0m' # No Color

          echo -e "$BLUE🔄 Syncing from origin (Gitea)...$NC"

          # Git fetch et reset
          if git fetch --all; and git reset --hard origin/main
            echo -e "$GREEN✓ Repository updated successfully!$NC"
            echo ""

            # Si on est sur magnolia, proposer de rebuild
            if test (hostname) = "magnolia"
              echo -e "$YELLOW🌸 You're on Magnolia - Do you want to rebuild the configuration?$NC"
              echo -e "$BLUE   This will apply the latest changes to the system.$NC"
              echo ""

              # Lire la réponse de l'utilisateur (y/N)
              read -l -P "Rebuild magnolia? [y/N] " confirm

              switch $confirm
                case Y y
                  echo ""
                  echo -e "$BLUE🔨 Rebuilding magnolia...$NC"
                  sudo nixos-rebuild switch --flake .#magnolia

                  if test $status -eq 0
                    echo ""
                    echo -e "$GREEN✓ Magnolia successfully rebuilt!$NC"
                  else
                    echo ""
                    echo -e "$YELLOW⚠ Rebuild failed. Check the errors above.$NC"
                  end
                case '*'
                  echo ""
                  echo -e "$BLUE ℹ Skipped rebuild. Run 'r' when you're ready.$NC"
              end
            end
          else
            echo -e "$YELLOW⚠ Git update failed!$NC"
            return 1
          end
        '';
      };
    };
  };
}
