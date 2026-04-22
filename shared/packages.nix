{ pkgs, lib, ... }:
let
  gitSquash = pkgs.fetchFromGitHub {
    owner = "sheerun";
    repo = "git-squash";
    rev = "e87fb1d410edceec3670101e2cf89297ecab5813";
    hash = "sha256-yvufKIwjP7VcIzLi8mE228hN4jmaqk90c8oxJtkXEP8=";
  };

  colorScript = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/nix-community/home-manager/b3a9fb9d05e5117413eb87867cebd0ecc2f59b7e/lib/bash/home-manager.sh";
    sha256 = "90ea66d50804f355801cd8786642b46991fc4f4b76180f7a72aed02439b67d08";
  };

  lazyworktree = pkgs.buildGoModule rec {
    pname = "lazyworktree";
    version = "1.14.0";

    src = pkgs.fetchFromGitHub {
      owner = "chmouel";
      repo = "lazyworktree";
      rev = "v${version}";
      hash = "sha256-lwz8tU1/PhDbLpyI1ZvCf3d5IqfGW+0pqI+q8TVQLSg=";
    };

    vendorHash = "sha256-qqbNqQ2dYNtot2yt5bOZDTbgze8ZrNZC5w22oRiiD3o=";

    # Tests require git which isn't available in sandbox
    doCheck = false;

    ldflags = [
      "-s"
      "-w"
      "-X main.version=${version}"
    ];

    meta = {
      description = "A simple Terminal UI to manage git worktrees";
      homepage = "https://github.com/chmouel/lazyworktree";
      license = lib.licenses.asl20;
      mainProgram = "lazyworktree";
    };
  };

  # Worktrunk - Git worktree management CLI for AI agent workflows
  worktrunk = pkgs.rustPlatform.buildRustPackage rec {
    pname = "worktrunk";
    version = "0.11.0";

    src = pkgs.fetchFromGitHub {
      owner = "max-sixty";
      repo = "worktrunk";
      rev = "v${version}";
      hash = "sha256-2u62yY7apD/9nsKv1AeohDe1JxqX+MG9dwhScqEX9sk=";
    };

    cargoHash = "sha256-G+dOTLhGO01WO4zMOMv6tU1R+Aopxo8fvG1S5qEXyig=";

    # Build dependencies:
    # - git: required by vergen-gitcl in build.rs for embedding git metadata
    nativeBuildInputs = [ pkgs.git ];

    # Tests require git repos
    doCheck = false;

    meta = {
      description = "Git worktree management CLI";
      homepage = "https://github.com/max-sixty/worktrunk";
      license = lib.licenses.mit;
      mainProgram = "wt";
    };
  };

  # ccusage - Usage analysis tool for Claude Code
  # Installed globally to avoid CPU-intensive npx calls on every statusline refresh
  ccusage = pkgs.stdenv.mkDerivation rec {
    pname = "ccusage";
    version = "18.0.5";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/ccusage/-/ccusage-${version}.tgz";
      hash = "sha256-Co9+jFDk4WmefrDnJvladjjYk+XHhYYEKNKb9MbrkU8=";
    };

    nativeBuildInputs = [ pkgs.nodejs ];

    unpackPhase = ''
      tar -xzf $src
    '';

    installPhase = ''
      mkdir -p $out/lib/node_modules/ccusage $out/bin
      cp -r package/* $out/lib/node_modules/ccusage/
      cat > $out/bin/ccusage <<EOF
      #!/usr/bin/env bash
      exec ${pkgs.nodejs}/bin/node $out/lib/node_modules/ccusage/dist/index.js "\$@"
      EOF
      chmod +x $out/bin/ccusage
    '';

    meta = {
      description = "Usage analysis tool for Claude Code";
      homepage = "https://github.com/ryoppippi/ccusage";
      license = lib.licenses.mit;
      mainProgram = "ccusage";
    };
  };

  # kamushadenes/pve-exporter - Go-based Proxmox VE metrics exporter (fork with PVE API SMART)
  pve-exporter-go = pkgs.buildGoModule rec {
    pname = "pve-exporter";
    version = "1.13.0";

    src = pkgs.fetchFromGitHub {
      owner = "kamushadenes";
      repo = "pve-exporter";
      rev = "c47c111793acb38a278ea89e72394ce02ad05d6b";
      hash = "sha256-US+z67vtPF9MfcqVb4+fllJNm6RyRzv7M+UlHkY5Zuw=";
    };

    vendorHash = "sha256-pi5Nj/FVvUGGXTVdin0JuaZQc8NPEqzjV1slO0pFvGE=";

    doCheck = false;

    ldflags = [
      "-s"
      "-w"
    ];

    meta = {
      description = "Prometheus exporter for Proxmox VE";
      homepage = "https://github.com/kamushadenes/pve-exporter";
      license = lib.licenses.mit;
      mainProgram = "pve-exporter";
    };
  };

  # RTK (Rust Token Killer) - Token-optimized CLI proxy for AI coding agents (60-90% savings)
  # Pre-built binary from GitHub releases (not in nixpkgs)
  rtk =
    let
      version = "0.35.0";
      sources = {
        "aarch64-darwin" = {
          url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-aarch64-apple-darwin.tar.gz";
          hash = "sha256-71tEudo9YvTuenvYIl0zHmYh5Ckjrys1izZRZLCEUMM=";
        };
        "x86_64-darwin" = {
          url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-x86_64-apple-darwin.tar.gz";
          hash = "sha256-v+bU2mvdUqIg00Vp6QR+QeG9x76MtBHCtiMiJdswE1E=";
        };
        "x86_64-linux" = {
          url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-x86_64-unknown-linux-musl.tar.gz";
          hash = "sha256-MMhSpvQVqKJwqqMzxhS7At/Q1gvFevOC9btEw7Yab/k=";
        };
        "aarch64-linux" = {
          url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-aarch64-unknown-linux-gnu.tar.gz";
          hash = "sha256-XFbaSRqaH585XKS+rOwITRE3haWxlPDo8qpTtP0TMsM=";
        };
      };
      src = pkgs.fetchurl sources.${pkgs.stdenv.hostPlatform.system};
    in
    pkgs.stdenv.mkDerivation {
      pname = "rtk";
      inherit version;
      inherit src;

      unpackPhase = ''
        tar -xzf $src
      '';

      installPhase = ''
        mkdir -p $out/bin
        cp rtk $out/bin/rtk
        chmod +x $out/bin/rtk
      '';

      meta = {
        description = "Token-optimized CLI proxy for LLM coding agents";
        homepage = "https://github.com/rtk-ai/rtk";
        license = lib.licenses.mit;
        mainProgram = "rtk";
      };
    };

  # better-ccflare - Claude API reverse proxy with load balancing
  # Pre-built binary from GitHub releases
  better-ccflare =
    let
      version = "3.4.10";
      sources = {
        "aarch64-darwin" = {
          url = "https://github.com/tombii/better-ccflare/releases/download/v${version}/better-ccflare-macos-arm64";
          hash = "sha256-811czfF8hK4YAhd4pDJ9cqvC3cbgguL5LMx/Y9O0T9A=";
        };
        "x86_64-darwin" = {
          url = "https://github.com/tombii/better-ccflare/releases/download/v${version}/better-ccflare-macos-x86_64";
          hash = "sha256-o+VzuJ1omf94ClVdzcjFOautU5BUz/fLI8Na4T6mWzI=";
        };
        "x86_64-linux" = {
          url = "https://github.com/tombii/better-ccflare/releases/download/v${version}/better-ccflare-linux-amd64";
          hash = "sha256-BITZo2C6n+mb5UOfk639mbKa/bNZlg2OIjM1IoamziI=";
        };
        "aarch64-linux" = {
          url = "https://github.com/tombii/better-ccflare/releases/download/v${version}/better-ccflare-linux-arm64";
          hash = "sha256-S5XCNgzHh2CO0Lyz6Rlm8qN8IfAC3JmWwdnKX5ur83I=";
        };
      };
      src = pkgs.fetchurl sources.${pkgs.stdenv.hostPlatform.system};
      unwrapped = pkgs.stdenv.mkDerivation {
        pname = "better-ccflare-unwrapped";
        inherit version;
        inherit src;
        dontUnpack = true;
        dontPatchELF = true;
        dontStrip = true;
        dontFixup = true;
        installPhase = ''
          mkdir -p $out/bin
          cp $src $out/bin/better-ccflare
          chmod +x $out/bin/better-ccflare
        '';
      };
    in
    # Bun single-file executable — patchelf corrupts the embedded app.
    # On Linux, wrap with buildFHSEnv for a proper /lib64 linker.
    # On Darwin, use the binary directly.
    if pkgs.stdenv.isLinux then
      pkgs.buildFHSEnv {
        name = "better-ccflare";
        inherit (unwrapped) meta;
        targetPkgs = _: [ ];
        runScript = "${unwrapped}/bin/better-ccflare";
      }
    else
      unwrapped;

  # Script to prepare a remote machine for this nix configuration
  # Copies age key, SSH key, creates nix.conf, clones repos, and provides activation instructions
  nix-remote-setup = pkgs.writeScriptBin "nix-remote-setup" ''
    #!${lib.getExe pkgs.bash}
    set -euo pipefail

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color

    # Logging functions matching deploy.py symbols
    log_info() { echo -e "''${BLUE}[ * ]''${NC} $1"; }
    log_success() { echo -e "''${GREEN}[ ✓ ]''${NC} $1"; }
    log_warn() { echo -e "''${YELLOW}[ ! ]''${NC} $1"; }
    log_error() { echo -e "''${RED}[ ✗ ]''${NC} $1"; }

    REMOTE_HOST="''${1:-}"

    if [[ -z "$REMOTE_HOST" ]]; then
        echo "Usage: nix-remote-setup <host>"
        echo ""
        echo "Prepares a remote machine to receive this nix configuration by:"
        echo "  1. Copying ~/.age/age.pem (age encryption key)"
        echo "  2. Copying ~/.ssh/keys/id_ed25519 (SSH key for private repo)"
        echo "  3. Creating ~/.config/nix/nix.conf"
        echo "  4. Cloning the nix config repo with submodules"
        echo "  5. Decrypting the cache signing key"
        echo ""
        echo "Prerequisites:"
        echo "  - SSH access to the remote host (configure port in ~/.ssh/config)"
        echo "  - Nix installed on the remote host"
        echo "  - Local ~/.age/age.pem and ~/.ssh/keys/id_ed25519 exist"
        exit 1
    fi

    # Verify local prerequisites
    if [[ ! -f "$HOME/.age/age.pem" ]]; then
        log_error "Local ~/.age/age.pem not found"
        exit 1
    fi

    if [[ ! -f "$HOME/.ssh/keys/id_ed25519" ]]; then
        log_error "Local ~/.ssh/keys/id_ed25519 not found"
        exit 1
    fi

    log_info "Setting up remote host: ''${BOLD}$REMOTE_HOST''${NC}"

    # Get remote home directory (uses SSH config for port/settings)
    log_info "Detecting remote home directory..."
    REMOTE_HOME=$(ssh "$REMOTE_HOST" 'echo $HOME')
    log_success "Remote home: $REMOTE_HOME"

    # Create required directories on remote
    log_info "Creating directories on remote..."
    ssh "$REMOTE_HOST" "mkdir -p ~/.age ~/.ssh/keys ~/.config/nix"
    log_success "Directories created"

    # Copy age key
    log_info "Copying age key..."
    scp "$HOME/.age/age.pem" "$REMOTE_HOST:~/.age/age.pem"
    ssh "$REMOTE_HOST" "chmod 600 ~/.age/age.pem"
    log_success "Age key copied"

    # Copy SSH key
    log_info "Copying SSH key..."
    scp "$HOME/.ssh/keys/id_ed25519" "$REMOTE_HOST:~/.ssh/id_ed25519"
    ssh "$REMOTE_HOST" "chmod 600 ~/.ssh/id_ed25519"
    log_success "SSH key copied"

    ssh "$REMOTE_HOST" "ssh-keyscan github.com >> ~/.ssh/known_hosts"

    # Create nix.conf with dynamic path
    log_info "Creating nix.conf..."
    ssh "$REMOTE_HOST" "cat > ~/.config/nix/nix.conf" <<EOF
    experimental-features = nix-command flakes
    substituters = https://ncps.hyades.io https://nix-community.cachix.org https://cache.nixos.org
    trusted-public-keys = ncps.hyades.io:/02vviGNLGYhW28GFzmPFupnP6gZ4uDD4G3kRnXuutE= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
    secret-key-files = $REMOTE_HOME/.config/nix/config/private/cache-priv-key.pem
    EOF
    log_success "nix.conf created"

    # Clone the repo
    log_info "Cloning nix config repository..."
    ssh "$REMOTE_HOST" "git clone --recursive git@github.com:kamushadenes/nix.git ~/.config/nix/config/"
    log_success "Repository cloned"

    # Decrypt cache signing key
    log_info "Decrypting cache signing key..."
    ssh "$REMOTE_HOST" 'AGE=$(find /nix/store -name "age" -type f -path "*/bin/*" 2>/dev/null | head -1); cd ~/.config/nix/config/private && $AGE -d -i ~/.age/age.pem cache-priv-key.pem.age > cache-priv-key.pem && chmod 600 cache-priv-key.pem'
    log_success "Cache key decrypted"

    echo ""
    log_success "Remote setup complete!"
    echo ""
    echo "To finish activation on the remote host, SSH in and run:"
    echo ""
    echo -e "''${YELLOW}For Darwin (macOS):''${NC}"
    echo "  1. Bootstrap nix-darwin first:"
    echo "     mkdir -p ~/.config/nix-darwin && cd ~/.config/nix-darwin"
    echo "     nix flake init -t nix-darwin"
    echo "     # Edit flake.nix: replace 'simple' with your hostname, add programs.nh.enable = true"
    echo "     nix run nix-darwin -- switch --flake ~/.config/nix-darwin"
    echo "  2. Log out and back in"
    echo "  3. Run: nh darwin switch --impure"
    echo "  4. Cleanup: rm -rf ~/.config/nix-darwin"
    echo ""
    echo -e "''${YELLOW}For NixOS:''${NC}"
    echo "  sudo nixos-rebuild switch --flake ~/.config/nix/config/ --impure"
  '';
in
{
  inherit
    gitSquash
    colorScript
    lazyworktree
    worktrunk
    ccusage
    rtk
    better-ccflare
    pve-exporter-go
    nix-remote-setup
    ;
}
