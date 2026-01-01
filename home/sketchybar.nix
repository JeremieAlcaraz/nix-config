{ config, lib, pkgs, ... }:

{
  xdg.configFile."sketchybar".source = ../modules/dotfiles/sketchybar;

  home.activation.sketchybarDependencies = lib.hm.dag.entryAfter ["writeBoundary"] ''
    set -euo pipefail

    font_path="${config.home.homeDirectory}/Library/Fonts/sketchybar-app-font.ttf"
    if [ ! -f "$font_path" ]; then
      ${pkgs.curl}/bin/curl -L \
        -o "$font_path" \
        "https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.5/sketchybar-app-font.ttf"
    fi

    lua_dir="${config.home.homeDirectory}/.local/share/sketchybar_lua"
    if [ ! -f "$lua_dir/sketchybar.so" ]; then
      tmp_dir="$(/usr/bin/mktemp -d)"
      ${pkgs.git}/bin/git clone https://github.com/FelixKratz/SbarLua.git "$tmp_dir/SbarLua"
      (cd "$tmp_dir/SbarLua" && ${pkgs.gnumake}/bin/make install)
      /bin/rm -rf "$tmp_dir"
    fi

    helpers_src="${config.xdg.configHome}/sketchybar/helpers"
    helpers_dst="${config.home.homeDirectory}/.local/share/sketchybar/helpers"
    if [ -d "$helpers_src" ]; then
      if [ -e "$helpers_dst" ]; then
        /bin/chmod -R u+w "$helpers_dst" || true
        /bin/rm -rf "$helpers_dst"
      fi
      /bin/mkdir -p "$helpers_dst"
      /bin/cp -R "$helpers_src"/. "$helpers_dst"/
      /bin/chmod -R u+w "$helpers_dst"
      (cd "$helpers_dst" && CC=/usr/bin/clang ${pkgs.gnumake}/bin/make)
    fi
  '';
}
