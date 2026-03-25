# System Architecture

This document provides a comprehensive deep-dive into the architecture of this
Nix flake configuration. It manages 26 systems across macOS, NixOS, and Proxmox
LXC containers using a role-based module composition system, ephemeral root
filesystems, and a private secrets management flow.

## Table of Contents

1. [Flake Entry Point](#flake-entry-point)
2. [Data Flow](#data-flow)
3. [System Layer](#system-layer)
4. [Home-Manager Layer](#home-manager-layer)
5. [Shared Utilities Layer](#shared-utilities-layer)
6. [Proxmox Architecture](#proxmox-architecture)
7. [Secrets Management](#secrets-management)
8. [Binary Cache](#binary-cache)
9. [Cross-Platform Patterns](#cross-platform-patterns)

## Flake Entry Point

The `flake.nix` file serves as the central entry point for the entire
configuration. It defines the inputs, outputs, and the factory functions used to
instantiate different types of hosts.

### Inputs

The configuration uses several key inputs to manage the system state:

```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";
  nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  darwin = {
    url = "github:LnL7/nix-darwin/nix-darwin-25.11";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  home-manager = {
    url = "github:nix-community/home-manager/release-25.11";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  agenix = {
    url = "github:ryantm/agenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

### Factory Functions

The flake defines four primary factory functions to create host configurations:

1.  **mkDarwinHost**: Creates macOS configurations using `nix-darwin`.
2.  **mkNixosHost**: Creates standard NixOS configurations.
3.  **mkProxmoxHost**: Creates NixOS configurations optimized for Proxmox VMs
    and LXCs, with optional ephemeral root and persistence.
4.  **mkDaemonLXCs**: A higher-level helper that generates identical LXC
    configurations across all Proxmox cluster nodes for high availability.

#### mkDarwinHost Signature

```nix
mkDarwinHost =
  {
    machine,
    role ? "workstation",
    shared ? false,
    system ? "aarch64-darwin",
  }:
  darwin.lib.darwinSystem {
    inherit system;
    specialArgs = {
      inherit inputs machine shared private role;
      claudebox = claudebox.packages.${system}.default;
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      platform = system;
    };
    modules = darwinModules;
  };
```

#### mkProxmoxHost Signature

This function includes specific logic for Proxmox guests, such as disabling
redundant services and enabling the persistence module.

```nix
mkProxmoxHost =
  {
    machine,
    hardware,
    role ? "headless",
    shared ? false,
    persistence ? true,
    extraPersistPaths ? [ ],
    system ? "x86_64-linux",
  }:
  nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = {
      inherit inputs machine shared private hardware role;
      # ... other args
    };
    modules = nixosModules ++ [
      # Proxmox specific overrides
      ({ lib, ... }: {
        services.fail2ban.enable = lib.mkForce false;
        networking.firewall.enable = lib.mkForce false;
        nix.settings.sandbox = "relaxed";
      })
    ] ++ (if persistence then [
      ./nixos/proxmox/persistence.nix
      ({ ... }: { proxmox.persistence.extraPaths = extraPersistPaths; })
    ] else [ ]);
  };
```

## Data Flow

The configuration follows a structured data flow from the flake entry point down
to individual role modules.

### ASCII Diagram

```text
flake.nix
   │
   ├─> private (builtins.fetchGit with submodules = true)
   │
   ├─> specialArgs (inputs, machine, shared, private, role, platform, pkgs-unstable, claudebox)
   │     │
   │     ├─> darwin.nix / nixos.nix (System Layer)
   │     │     │
   │     │     └─> home-manager (home.nix)
   │     │           │
   │     │           └─> shared/roles.nix (Role Modules)
   │     │                 │
   │     │                 ├─> workstation
   │     │                 ├─> headless
   │     │                 └─> minimal
   │
   └─> shared/helpers.nix (Utilities)
```

### Private Submodule Access

The `private` directory is a git submodule containing encrypted secrets. Because
Nix flakes don't include submodule contents by default when copying to the Nix
store, the flake uses `builtins.fetchGit` to access it:

```nix
private =
  builtins.fetchGit {
    url = "file://${builtins.getEnv "HOME"}/.config/nix/config";
    submodules = true;
    ref = "main";
  }
  + "/private";
```

This `private` path is passed through `specialArgs` to all modules, allowing
them to reference secrets using `"${private}/path/to/secret.age"`.

## System Layer

The system layer handles platform-specific configurations for macOS and NixOS.

### Darwin (macOS)

The `darwin.nix` file imports 24 modules that configure everything from Homebrew
and the Dock to security settings and window management.

```nix
imports = [
  ./shared/build.nix
  ./shared/cache.nix

  ./darwin/brew.nix
  ./darwin/dock.nix
  ./darwin/settings.nix
  ./darwin/tiling.nix
  # ... 20 more modules
];
```

It also configures a Linux builder VM to enable cross-platform builds (like
building NixOS images from a Mac):

```nix
nix.linux-builder = {
  enable = true;
  package = pkgs-unstable.darwin.linux-builder;
  systems = [ "x86_64-linux" "aarch64-linux" ];
  config = { lib, ... }: {
    boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
    virtualisation = {
      cores = lib.mkForce 4;
      memorySize = lib.mkForce 8192;
    };
  };
};
```

### NixOS

The `nixos.nix` file uses role-based logic to conditionally import modules. This
ensures that minimal service containers don't include desktop environments or
heavy development tools.

```nix
let
  isHeadless = role == "headless";
  isMinimal = role == "minimal";
  isServer = isHeadless || isMinimal;
in
{
  imports = [
    hardware
    ./shared/build.nix
    ./shared/cache.nix
    # Core modules
    ./nixos/nix.nix
    ./nixos/security.nix
    ./nixos/shells.nix
    ./nixos/users.nix
  ]
  ++ lib.optionals (!isServer) [
    ./nixos/dev.nix
    ./nixos/fonts.nix
    ./nixos/audio.nix
    ./nixos/display_gnome.nix
    # ... other GUI modules
  ]
  ++ lib.optionals isMinimal [
    ./nixos/minimal.nix
  ];
}
```

## Home-Manager Layer

The `home.nix` file manages user-level configuration and uses a role-based
composition system defined in `shared/roles.nix`. For a complete catalog of
every module, see the [Module Reference](./modules.md).

### Module Composition

The `roles.mkRoleModules` function takes the `role` and `platform` and returns a
list of modules to import.

```nix
# shared/roles.nix
mkRoleModules = { role, platform }:
  let
    groups = {
      workstation = base ++ ai ++ dev ++ editors ++ infra ++ utils ++ sync ++ media ++ guiShell ++ ...;
      headless = base ++ ai ++ dev ++ editors ++ infra ++ utils ++ sync ++ ...;
      minimal = coreMinimal ++ shellMinimal ++ ...;
    };
  in
    groups.${role};
```

### Module Arguments

The `_module.args` attribute provides several helpers and shared configurations
to all home-manager modules:

```nix
_module.args = {
  inherit helpers;      # shared/helpers.nix
  inherit packages;     # shared/packages.nix
  inherit shellCommon;  # shared/shell-common.nix
  inherit themes;       # shared/themes.nix
  inherit fishPlugins;  # shared/fish-plugins.nix
  inherit pkgs-unstable;
};
```

## Shared Utilities Layer

The `shared/` directory contains utilities used across both system and
home-manager layers.

### helpers.nix

Provides a factory for global variables, YAML/TOML conversion functions, and
theme definitions.

```nix
globalVariables = {
  base = {
    EDITOR = "nvim";
    NH_FLAKE = "${config.home.homeDirectory}/.config/nix/config/?submodules=1";
    # ...
  };
  shell = mkVarExports (name: value: ''export ${name}="${value}"'') globalVariables.base;
  fishShell = mkVarExports (name: value: ''set -x ${name} "${value}"'') globalVariables.base;
};
```

### shell-common.nix

Manages shared shell functions. Because Fish syntax is incompatible with
Bash/Zsh, this module reads separate `.fish` and `.sh` files from
`resources/shell/` and applies them to the respective shell configurations.

### cache.nix

Configures the binary cache settings, including the self-hosted NCPS cache and a
post-build hook for automatic uploads.

```nix
uploadToCache = pkgs.writeShellScript "upload-to-cache" ''
  echo "Uploading to NCPS:" $OUT_PATHS
  ${config.nix.package}/bin/nix copy --to 'https://ncps.hyades.io' $OUT_PATHS || true
'';
```

### build.nix

Defines distributed build configurations. While currently set to local builds,
it includes helpers for defining remote Darwin and Linux build machines.

### packages.nix

Contains custom package definitions, such as `lazyworktree`, `worktrunk`,
`ccusage`, and `pve-exporter`.

### age-home.nix

A patched version of the agenix home-manager module. It fixes a crash loop that
occurs when stale generation directories reference secrets that can no longer be
decrypted. It ensures that stale directories are cleaned up before new ones are
created.

## Proxmox Architecture

The Proxmox infrastructure uses an ephemeral root model for LXC containers and
VMs. For per-service details (ports, secrets, health checks), see the
[Service Reference](./services.md).

### Persistence Model

The `nixos/proxmox/persistence.nix` module implements a tmpfs root with
bind-mounted persistence from `/nix/persist`.

```nix
basePaths = [
  "/etc/nixos"
  "/var/lib/systemd"
  "/var/log"
  "/home"
];

createPersistDirsScript = pkgs.writeShellScript "create-persist-dirs" ''
  ${lib.concatMapStringsSep "\n" (p: "mkdir -p /nix/persist${p}") allPaths}
  # ... generate machine-id and SSH keys if missing
'';
```

The `create-persist-dirs` systemd service runs early in the boot process to
ensure directories exist before they are bind-mounted.

### Daemon LXC Pattern

The `mkDaemonLXCs` helper in `flake.nix` generates identical configurations for
services that run on all three Proxmox nodes (pve1, pve2, pve3). This is used
for high-availability services like `cloudflared` and `tailscale`.

### Image Builders

The configuration includes builders for Proxmox LXC tarballs and VM qcow2
images:

```nix
proxmox-lxc = nixos-generators.nixosGenerate {
  system = "x86_64-linux";
  format = "proxmox-lxc";
  modules = [ ./nixos/proxmox/lxc.nix ];
};
```

## Secrets Management

Secrets are managed using `agenix` with age encryption.

### Flow

1.  **Identity**: The age identity is stored at `~/.age/age.pem`.
2.  **Encryption**: Secrets are stored as `.age` files in the `private/`
    submodule.
3.  **Decryption**: Secrets are decrypted at activation time.
4.  **Mounting**: On macOS, secrets are mounted to `DARWIN_USER_TEMP_DIR`. On
    Linux, they are mounted to `XDG_RUNTIME_DIR`.

### lxc-add-machine

A helper script, `lxc-add-machine`, automates the process of adding a new
machine to the secrets recipients list by fetching its SSH host key and
re-encrypting the relevant secrets.

## Binary Cache

The configuration uses a self-hosted Nix Cache Proxy Server (NCPS) at
`ncps.hyades.io`.

### NCPS Flow

- **Upload**: A `post-build-hook` automatically uploads successful builds to
  NCPS.
- **Signing**: The cache signing key is stored in the `private/` submodule and
  decrypted by the `rebuild` tool.
- **Substituters**: The system is configured to check NCPS first, then Cachix,
  and finally the official NixOS cache.

```nix
substituters = [
  "https://ncps.hyades.io"
  "https://nix-community.cachix.org"
  "https://cache.nixos.org"
];
```

## Cross-Platform Patterns

The configuration employs several patterns to handle the differences between
Darwin and Linux.

### Shell Compatibility

As mentioned in the Shared Utilities section, shell functions are maintained in
separate files to accommodate Fish's unique syntax.

### Template Substitution

The `applySubst` helper in `helpers.nix` allows for dynamic value substitution
in script templates using `@placeholder@` syntax. This is used extensively in
the `rebuild` tool and shell functions.

### Theme Consistency

The Catppuccin Macchiato theme is applied globally. To handle different naming
conventions across various tools, `helpers.nix` provides pre-computed variant
names:

```nix
variants = {
  underscore = "catppuccin_macchiato"; # btop, starship
  hyphen = "catppuccin-macchiato";     # ghostty, git
  titleSpace = "Catppuccin Macchiato"; # bat
  variantOnly = "macchiato";           # yazi
};
```

### Linux Builder

The inclusion of the `nix.linux-builder` VM on Darwin machines is a critical
pattern that allows for seamless cross-compilation and deployment of NixOS
systems from a macOS workstation.
