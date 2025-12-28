# Reverse macOS defaults (nix-darwin)

This note documents a repeatable way to discover the `defaults` keys behind
System Settings so you can wire them into nix-darwin.

## 1) Capture "before"

Use `/bin/ls` (or `command ls`) to bypass any `ls` alias like `eza`.

```sh
defaults read -g > /tmp/global.before
defaults read com.apple.finder > /tmp/finder.before
/bin/ls -lt ~/Library/Preferences ~/Library/Preferences/ByHost | head -40 > /tmp/prefs.before
```

## 2) Change one setting in System Settings

Change a single toggle or color so the diff is easy to read.

## 3) Capture "after"

```sh
defaults read -g > /tmp/global.after
defaults read com.apple.finder > /tmp/finder.after
/bin/ls -lt ~/Library/Preferences ~/Library/Preferences/ByHost | head -40 > /tmp/prefs.after
```

## 4) Diff

```sh
diff -u /tmp/global.before /tmp/global.after
diff -u /tmp/finder.before /tmp/finder.after
diff -u /tmp/prefs.before /tmp/prefs.after
```

## 5) Identify the domain and keys

Common cases:
- `defaults read -g` diffs map to `NSGlobalDomain`.
- `defaults read com.apple.finder` diffs map to `com.apple.finder`.
- If neither changed, look at `/tmp/prefs.before` vs `/tmp/prefs.after` to find
  updated plists, then inspect them with:

```sh
defaults read <domain>
plutil -p ~/Library/Preferences/<domain>.plist
```

If the change is stored in `ByHost`, use `-currentHost`:

```sh
defaults -currentHost read <domain>
```

## 6) Add to nix-darwin

Put the keys into your host config (example):

```nix
system.defaults.CustomUserPreferences."NSGlobalDomain" = {
  SomeKey = "Value";
};
```

For a specific domain:

```nix
system.defaults.CustomUserPreferences."com.apple.finder" = {
  SomeKey = 1;
};
```

## 7) Apply

```sh
darwin-rebuild switch --flake .#marigold
```

Optional if the app does not pick up changes automatically:

```sh
killall Finder
```

## Example: Folder color

Changing "Folder colour" in Appearance updates `NSGlobalDomain`:

```text
AppleIconAppearanceTintColor
AppleIconAppearanceCustomTintColor
```

These can be set in nix-darwin under `NSGlobalDomain`.

## More examples (common defaults keys)

These are common keys you can confirm with the same diff workflow.

### Dock: auto-hide

Domain: `com.apple.dock`

```nix
system.defaults.CustomUserPreferences."com.apple.dock" = {
  autohide = true;
};
```

### Dock: icon size

Domain: `com.apple.dock`

```nix
system.defaults.CustomUserPreferences."com.apple.dock" = {
  tilesize = 64;
};
```

### Finder: show hidden files

Domain: `com.apple.finder`

```nix
system.defaults.CustomUserPreferences."com.apple.finder" = {
  AppleShowAllFiles = true;
};
```

### Finder: default view style

Domain: `com.apple.finder`

```nix
system.defaults.CustomUserPreferences."com.apple.finder" = {
  FXPreferredViewStyle = "Nlsv"; # icnv, Nlsv, clmv, Flwv
};
```

### Accent and highlight colors

Domain: `NSGlobalDomain`

```nix
system.defaults.CustomUserPreferences."NSGlobalDomain" = {
  AppleAccentColor = 6; # Pink
  AppleHighlightColor = "1.000000 0.749020 0.823529 Pink";
};
```
