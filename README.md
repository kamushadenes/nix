# Nix Configuration

This is my Nix configuration for both Darwin and NixOS.

The `private` folder is a submodule pointing to a private repo that contains encrypted keys and stuff. It's symlinked to from other places around the config, meaning that the config won't work as-is for someone that doesn't have access to that private repo (hopefully no one but me).

Still, the config has some niceties so I thought it would be cool to share. Enjoy!

## Install

Make sure that both `~/.age/age.pem` and `~/.ssh/keys/id_ed25519` are in place.

```sh
mkdir -p ~/.config/nix

echo > ~/.config/nix/nix.conf <<EOF
experimental-features = nix-command flakes
substituters = http://ncps.hyades.io:8501 https://nix-community.cachix.org https://cache.nixos.org
trusted-public-keys = ncps.hyades.io:/02vviGNLGYhW28GFzmPFupnP6gZ4uDD4G3kRnXuutE= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
secret-key-files = /Users/kamushadenes/.config/nix/config/private/cache-priv-key.pem
EOF

git clone --recursive git@github.com:kamushadenes/nix.git ~/.config/nix/config/
```

### Darwin

You need to install a default nix-darwin first, because we need nh-plus.

```sh
mkdir -p ~/.config/nix-darwin
cd ~/.config/nix-darwin
nix flake init -t nix-darwin
sed -i '' "s/simple/$(scutil --get LocalHostName)/" flake.nix
```

Edit flake.nix, and add the following input:

```nix
nh-plus.url = "github:ToyVo/nh_darwin";
```

Edit the outputs inputs:

```nix
outputs = inputs@{ self, nix-darwin, nixpkgs, nh-plus }:
```

Enable nh:

```nix
programs.nh.enable = true;
```

And finally the module:

```nix
modules = [ configuration nh-plus.nixDarwinModules.prebuiltin ];
```

Also, make sure to fix the platform.

Now, run the initial switch:

```sh
nix run nix-darwin -- switch --flake ~/.config/nix-darwin
```

Logout and login again, then run the real install (will take some time):

```sh
export NH_FLAKE="$HOME/.config/nix/config/?submodules=1"

nh os switch -H (hostname -s | sed s"/.local//g")
# OR
nh darwin switch -H (hostname -s | sed s"/.local//g")
```

Then cleanup:

```sh
rm -rf ~/.config/nix-darwin
```

### NixOS

```sh
sudo nixos-rebuild switch --flake ~/.config/nix/config/
```

## Apply Changes

```sh
rebuild
```

**Note:** The `rebuild` alias automatically includes `--impure` which is required for the `private/` submodule access via `builtins.fetchGit`.

If rebuilding manually:

```sh
# With nh (recommended)
nh darwin switch --impure

# With darwin-rebuild
darwin-rebuild switch --flake .#$(hostname -s) --impure

# With nixos-rebuild
sudo nixos-rebuild switch --flake . --impure
```

## Private Submodule

The `private/` directory is a git submodule containing encrypted secrets and sensitive configurations. Due to limitations with nix flakes and git submodules, the flake uses `builtins.fetchGit` with `submodules = true` to access these files.

### How It Works

1. The flake fetches the entire repo with submodules using `builtins.fetchGit`
2. A `private` variable is passed through `specialArgs` to all modules
3. Modules reference private files using `"${private}/path/to/file"` instead of symlinks

### Adding New Private Resources

When adding new files to the `private/` submodule:

1. Add and commit files in the `private/` submodule first
2. In modules, use `"${private}/relative/path"` to reference the file
3. Add `private` to the module's function parameters: `{ config, pkgs, private, ... }:`
4. Commit the submodule reference update in the main repo
5. Rebuild with `--impure` flag
