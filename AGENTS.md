# Nix Config

Nix flake managing Darwin/NixOS systems with home-manager. Uses agenix for secrets.

**Machines:** `studio`, `macbook-m3-pro`, `w-henrique` (aarch64-darwin), x86_64-linux

## Commands

```bash
rebuild                    # Preferred - run via tmux MCP in fish shell
nh darwin switch --impure  # Alternative Darwin rebuild
```

## Structure

```
flake.nix          # Entry point
├── darwin.nix     # Darwin system config
├── nixos.nix      # NixOS system config
├── home.nix       # Home-manager base
├── shared/        # helpers.nix, build.nix, cache.nix, packages.nix, themes.nix
├── darwin/        # Darwin-specific modules
├── nixos/         # NixOS-specific modules
├── home/common/   # Cross-platform: ai/, core/, shell/, dev/, editors/, infra/, security/
└── private/       # Git submodule with encrypted secrets
```

## Key Patterns

**Module args:** `machine`, `shared`, `pkgs-unstable`, `inputs`, `platform`, `private`

**Private submodule:** Add `private` to module params, reference as `"${private}/path"`. Requires `--impure`.

**Secrets:** Age-encrypted in `private/`, identity at `~/.age/age.pem`

## Conventions

- Modules self-contained, grouped by function
- Static files in `resources/` subdirectories
- Primary shell: Fish; primary editor: Neovim
