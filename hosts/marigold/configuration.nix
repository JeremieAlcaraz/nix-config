{ config, pkgs, ... }:
let
  brewBin = if pkgs.stdenv.hostPlatform.isAarch64 then "/opt/homebrew/bin" else "/usr/local/bin";
in {
  nixpkgs.config.allowUnfree = true;

  homebrew = {
    enable = true;
    caskArgs = {
      appdir = "/Applications";
    };
    taps = [
      "felixkratz/formulae"
      "nikitabobko/tap"
    ];
    brews = [
      "borders"
      "lua"
      "nowplaying-cli"
      "sketchybar"
      "switchaudio-osx"
    ];
    casks = [
      "1password"
      "nikitabobko/tap/aerospace@0.19.2"
      "font-sf-mono"
      "font-sf-pro"
      "hammerspoon"
      "sf-symbols"
    ];
  };

  security.pam.enableSudoTouchIdAuth = true; # Use Touch ID for sudo authentication.
  fonts.packages = [ pkgs.fira-code pkgs.jetbrains-mono ]; # Install monospace fonts.

  # === macOS global defaults (NSGlobalDomain) ===
  system.defaults.NSGlobalDomain = {
    AppleShowAllExtensions = true; # Always show file extensions in Finder.
    AppleInterfaceStyleSwitchesAutomatically = true; # Auto-switch light/dark.
    KeyRepeat = 1; # Fast key repeat rate.
    NSAutomaticCapitalizationEnabled = true; # Enable auto-capitalization.
    NSAutomaticPeriodSubstitutionEnabled = true; # Enable double-space -> period.
    NSAutomaticSpellingCorrectionEnabled = false; # Disable auto-correct.
    NSAutomaticWindowAnimationsEnabled = false; # Disable window animations.
  };

  # === Custom global defaults not exposed by nix-darwin ===
  system.defaults.CustomUserPreferences."NSGlobalDomain" = {
    AppleAccentColor = 6; # Accent color index (6 = pink).
    AppleHighlightColor = "0.819608 0.466667 0.603922 D1779A"; # Highlight color (RGB + name).
    AppleIconAppearanceTintColor = "Other";
    AppleIconAppearanceCustomTintColor = "0.819608 0.466667 0.603922 1.000000"; # #d1779a RGBA
  };

  users.users.jeremiealcaraz.home = "/Users/jeremiealcaraz";

  system.defaults.CustomUserPreferences."org.hammerspoon.Hammerspoon" = {
    MJConfigFile = "${config.users.users.jeremiealcaraz.home}/.config/hammerspoon/init.lua";
  };

  # Obligatoire pour ne pas casser l'install Determinate
  nix.enable = false;

  system.stateVersion = 4;
}
