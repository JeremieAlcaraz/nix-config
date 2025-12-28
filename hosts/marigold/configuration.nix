{ config, pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  homebrew = {
    enable = true;
    casks = [ "1password" "hammerspoon" ];
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
    AppleHighlightColor = "1.000000 0.749020 0.823529 Pink"; # Highlight color (RGB + name).
  };

  users.users.jeremiealcaraz.home = "/Users/jeremiealcaraz";

  system.defaults.CustomUserPreferences."org.hammerspoon.Hammerspoon" = {
    MJConfigFile = "${config.users.users.jeremiealcaraz.home}/.config/hammerspoon/init.lua";
  };

  # Obligatoire pour ne pas casser l'install Determinate
  nix.enable = false;

  system.stateVersion = 4;
}
