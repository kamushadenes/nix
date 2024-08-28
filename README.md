# Nix Configuration

This is my Nix configuration for both Darwin and NixOS.

The `private` folder is a submodule pointing to a private repo that contains encrypted keys and stuff. It's symlinked to from other places around the config, meaning that the config won't work as-is for someone that doesn't have access to that private repo (hopefully no one but me).

Still, the config has some niceties so I thought it would be cool to share. Enjoy!

## Install

Make sure that both `~/.age/age.pem` and `~/.ssh/keys/id_ed25519` are in place.

```sh
mkdir -p ~/.config/nix

echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf

git clone git@github.com:kamushadenes/nix.git ~/.config/nix/config/
```

### Darwin

```sh
nix run nix-darwin -- switch --flake ~/.config/nix/config/
```

### NixOS

```sh
sudo nixos-rebuild switch --flake ~/.config/nix/config/
```

## Apply Changes

```sh
rebuild
```
