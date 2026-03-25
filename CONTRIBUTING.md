# Contributing Guide

This repository manages a personal Nix configuration for multiple Darwin and
NixOS systems. Follow these guidelines to maintain consistency and ensure
successful deployments.

## Prerequisites

You need the following setup before contributing:

- Nix with flakes enabled.
- Age encryption identity key at `~/.age/age.pem`.
- SSH key at `~/.ssh/keys/id_ed25519` for private repository access.
- Access to the `private` git submodule.

## Repository Structure

The configuration is organized into system-specific modules and shared
utilities.

- `flake.nix`: Entry point defining inputs and machine configurations.
- `darwin/`: macOS system modules.
- `nixos/`: NixOS system modules and machine definitions.
- `home/`: Home-manager modules for user-level configuration.
- `shared/`: Cross-platform utilities and role definitions.
- `private/`: Encrypted secrets and sensitive configurations (git submodule).

See `docs/architecture.md` for a detailed breakdown of the architecture.

## Development Workflow

### Making and Testing Changes

Use the `rebuild` tool to apply and test changes. It handles the necessary flags
and environment setup automatically.

```bash
rebuild
```

### Git and Nix Flakes

Nix flakes only evaluate files tracked by git. You must stage and commit new
files before Nix can see them. Modified existing files work without committing.

### Private Submodule

The `private/` directory is a separate git submodule. Commit changes in the
submodule first, then update the reference in the main repository.

### Pre-commit Hooks

This project uses `lefthook` to enforce code quality. It runs `nixfmt` on all
modified `.nix` files before every commit.

## Adding a New Module

1. Create the `.nix` file in the appropriate directory under `home/common/`,
   `darwin/`, or `nixos/`.
2. Register the module in `shared/roles.nix` under the correct module group
   (e.g., `dev`, `infra`, `utils`).
3. Run `git add` on the new file before attempting a rebuild.

Refer to `docs/modules.md#adding-a-new-module` for step-by-step instructions.

## Adding a New Machine

- **Darwin**: Add a new entry to `darwinConfigurations` in `flake.nix` using
  `mkDarwinHost`.
- **NixOS**: Add a new entry to `nixosConfigurations` in `flake.nix` using
  `mkNixosHost`.
- **Proxmox LXC**: Use the `mkProxmoxHost` helper in `flake.nix`. You must
  create a hardware configuration in `nixos/hardware/` and a machine
  configuration in `nixos/machines/`.

See `docs/operations.md` for full procedures on machine provisioning.

## Secrets Management

This project uses `agenix` with age encryption for all sensitive data.

- Never commit plaintext secrets to the repository.
- Store encrypted `.age` files in the `private/` submodule.
- Use the `@PLACEHOLDER@` syntax for secret substitution in configuration files.

Detailed instructions are available in `docs/operations.md#secrets-management`.

## Code Style

- **Formatting**: `nixfmt` is enforced via a pre-commit hook.
- **Organization**: Modules should be self-contained and grouped by
  functionality.
- **Resources**: Place static files in `resources/` subdirectories within their
  respective modules.
- **Private Access**: Use the `private` variable passed through `specialArgs` to
  reference sensitive files. Do not use symlinks.

## Commit Conventions

Use conventional commit format for all changes:

- `feat:`: New features or modules.
- `fix:`: Bug fixes.
- `chore:`: Maintenance tasks or dependency updates.
- `docs:`: Documentation changes.
- `refactor:`: Code restructuring without functional changes.

Keep commit messages concise and descriptive.

## Testing Changes

- Run `rebuild` to test changes on the current machine.
- Use `nix flake check` to validate the flake syntax and dependencies.
- For remote machines, run `rebuild -n <machine>` to perform a dry run before
  deploying.
