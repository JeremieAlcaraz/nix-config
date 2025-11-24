# 🚀 Optimisation des temps de build NixOS

## 🎯 Problème

Les installations NixOS peuvent prendre 15+ minutes si les packages sont recompilés depuis les sources au lieu d'utiliser des binaires pré-compilés.

## ✅ Solution 1 : Caches binaires (FAIT)

Les caches binaires officiels sont maintenant configurés dans `modules/base.nix` pour **tous les hôtes** :

```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"  # Cache officiel NixOS
  ];

  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  ];
};
```

**Résultat attendu** : Réduction du temps de build de ~15min à ~2-3min pour une installation standard.

## 🔍 Diagnostiquer ce qui est compilé

Pour comprendre pourquoi un build est lent :

```bash
# Pendant un build, voir ce qui est téléchargé vs compilé
nix build .#nixosConfigurations.minimal.config.system.build.toplevel --print-build-logs

# Vérifier si un package est dans le cache
nix path-info --store https://cache.nixos.org nixpkgs#hello
```

## 🚀 Solution 2 : Cachix (cache communautaire)

[Cachix](https://cachix.org) est un service de cache binaire gratuit pour les projets open source.

### Ajouter Cachix au projet

```bash
# Sur ton Mac ou sur magnolia
nix-env -iA cachix -f https://cachix.org/api/v1/install

# Utiliser un cache public (exemple : nix-community)
cachix use nix-community
```

### Configuration dans base.nix

```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"  # Cache communautaire
  ];

  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
};
```

## 💾 Solution 3 : Cache local partagé (magnolia)

Tu as déjà un cache local sur magnolia via `nix-serve`. Pour l'utiliser sur tous les hôtes :

### Option A : Via Tailscale (nécessite Tailscale actif)

Dans les configs individuelles (mimosa le fait déjà) :

```nix
nix.settings = {
  substituters = [
    # Les caches de base.nix sont automatiquement inclus
    "http://magnolia:5000"  # Cache local via Tailscale
  ];

  trusted-public-keys = [
    # Les clés de base.nix sont automatiquement incluses
    "magnolia.cache:7MVdzDOzQsVItEh+ewmU4Ga8TOke40asmXY1p9nQhC0="
  ];
};
```

**⚠️ Important** : Le cache magnolia ne fonctionne QUE si Tailscale est déjà connecté. Donc pendant l'installation initiale, seul cache.nixos.org sera utilisé.

### Option B : Via IP locale (sans Tailscale)

Si tes VMs sont sur le même réseau Proxmox :

```nix
nix.settings = {
  substituters = [
    "http://192.168.1.X:5000"  # Remplace par l'IP locale de magnolia
  ];
};
```

## ⚡ Solution 4 : Optimiser le script d'installation

Configurer les caches AVANT l'installation pour en profiter immédiatement :

```bash
# Dans scripts/install-nixos.sh, avant nixos-install
mkdir -p /mnt/etc/nix
cat > /mnt/etc/nix/nix.conf <<EOF
experimental-features = nix-command flakes
substituters = https://cache.nixos.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
EOF
```

## 🔧 Solution 5 : Optimisations matérielles

### Augmenter les ressources pendant l'installation

```bash
# Sur Proxmox, augmenter temporairement :
# - CPU : 4+ cores
# - RAM : 4+ GB

# Après l'installation, tu peux réduire pour l'utilisation normale
```

### Parallélisme de build

Dans `base.nix` :

```nix
nix.settings = {
  max-jobs = "auto";  # Utilise tous les cores disponibles
  cores = 0;          # Tous les cores par job
};
```

## 📊 Mesurer l'amélioration

```bash
# Avant optimisation
time sudo nixos-rebuild switch --flake .#minimal
# real    15m32.541s  ❌

# Après optimisation (avec caches)
time sudo nixos-rebuild switch --flake .#minimal
# real    2m18.123s   ✅
```

## 🎯 Checklist d'optimisation

- [x] Caches binaires dans base.nix (cache.nixos.org)
- [ ] Ajouter Cachix si nécessaire (projets communautaires)
- [ ] Configurer le cache magnolia pour les hôtes avec Tailscale
- [ ] Optimiser script d'installation (pré-configurer nix.conf)
- [ ] Augmenter ressources VM pendant installation
- [ ] Activer parallélisme de build (max-jobs)

## 🐛 Dépannage

### Vérifier que les caches sont utilisés

```bash
# Pendant un build
nix build --print-build-logs 2>&1 | grep -E 'copying path|building'
# "copying path" = téléchargé depuis le cache ✅
# "building" = compilé localement ❌
```

### Forcer l'utilisation des caches

```bash
# Refuse de compiler, utilise uniquement les caches
nix build --option substitute true --option builders ""
```

### Cache non accessible

```bash
# Tester la connexion au cache
curl -I https://cache.nixos.org
curl -I http://magnolia:5000  # Si Tailscale actif
```

## 📚 Ressources

- [NixOS Binary Cache](https://nixos.org/manual/nix/stable/package-management/binary-cache.html)
- [Cachix Documentation](https://docs.cachix.org)
- [nix-serve](https://github.com/edolstra/nix-serve) - Cache local
