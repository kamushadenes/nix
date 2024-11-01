# Nix Configuration

This is my Nix configuration for both Darwin and NixOS.

The `private` folder is a submodule pointing to a private repo that contains encrypted keys and stuff. It's symlinked to from other places around the config, meaning that the config won't work as-is for someone that doesn't have access to that private repo (hopefully no one but me).

Still, the config has some niceties so I thought it would be cool to share. Enjoy!

## Install

Make sure that both `~/.age/age.pem` and `~/.ssh/keys/id_ed25519` are in place.

```sh
mkdir -p ~/.config/nix

echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf

git clone --recursive git@github.com:kamushadenes/nix.git ~/.config/nix/config/
```

### Darwin

You need to install a default nix-darwin first, otherwise it won't recognize the private submodules.

``` sh
mkdir -p ~/.config/nix-darwin
cd ~/.config/nix-darwin
nix flake init -t nix-darwin
sed -i '' "s/simple/$(scutil --get LocalHostName)/" flake.nix
```

Make sure to fix the platform in flake.nix, then run the initial switch.

``` sh
nix run nix-darwin -- switch --flake ~/.config/nix-darwin
```

Logout and login again, then, run the real install.

```sh
darwin-rebuild switch --flake ~/.config/nix/config/\?submodules=1
```

Then cleanup.

``` sh
rm -rf ~/.config/nix-darwin
```

`

### NixOS

```sh
sudo nixos-rebuild switch --flake ~/.config/nix/config/
```

## Apply Changes

```sh
rebuild
```
