{ config, pkgs, ... }:

let
  yaziSource = ../modules/dotfiles/yazi;
in
{
  home.packages = with pkgs; [
    unstable.yazi
  ];

  # Deploy yazi config as writable files (needed for ya pkg to manage package.toml)
  home.activation.yaziConfig = config.lib.dag.entryAfter ["writeBoundary"] ''
    YAZI_CONFIG="${config.xdg.configHome}/yazi"
    YAZI_SOURCE="${yaziSource}"

    # Remove old config (symlink or directory)
    if [ -e "$YAZI_CONFIG" ]; then
      $DRY_RUN_CMD rm -rf "$YAZI_CONFIG"
    fi

    # Copy config as writable files
    echo "Deploying yazi config..."
    $DRY_RUN_CMD mkdir -p "${config.xdg.configHome}"
    $DRY_RUN_CMD cp -r "$YAZI_SOURCE" "$YAZI_CONFIG"
    $DRY_RUN_CMD chmod -R u+w "$YAZI_CONFIG"

    # Install plugins via ya pkg
    if [ -f "$YAZI_CONFIG/package.toml" ]; then
      echo "Installing yazi plugins..."
      export PATH="${pkgs.git}/bin:$PATH"
      $DRY_RUN_CMD ${pkgs.unstable.yazi}/bin/ya pkg install
    fi
  '';
}
