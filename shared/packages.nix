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

  # Happy Coder CLI - Mobile and Web client wrapper for Claude Code and Codex
  # Built from the happy-cli repository (not the main happy repo)
  happy-coder = pkgs.mkYarnPackage rec {
    pname = "happy-coder";
    version = "0.13.0";

    src = pkgs.fetchFromGitHub {
      owner = "slopus";
      repo = "happy-cli";
      rev = "f9cb1216bdaacd885cd55d7eae676ad6c675a48a"; # v0.13.0 commit
      hash = "sha256-q4o8FHBhZsNL+D8rREjPzI1ky5+p3YNSxKc1OlA2pcs=";
    };

    offlineCache = pkgs.fetchYarnDeps {
      yarnLock = "${src}/yarn.lock";
      hash = "sha256-DlUUAj5b47KFhUBsftLjxYJJxyCxW9/xfp3WUCCClDY=";
    };

    buildPhase = ''
      export HOME=$PWD
      yarn --offline run build
    '';

    distPhase = "true"; # Skip the default dist phase

    meta = {
      description = "Mobile and Web client for Claude Code and Codex";
      homepage = "https://github.com/slopus/happy-cli";
      license = lib.licenses.mit;
      mainProgram = "happy";
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

    # Parse host:port format
    INPUT="''${1:-}"

    if [[ -z "$INPUT" ]]; then
        echo "Usage: nix-remote-setup <user@host[:port]>"
        echo ""
        echo "Prepares a remote machine to receive this nix configuration by:"
        echo "  1. Copying ~/.age/age.pem (age encryption key)"
        echo "  2. Copying ~/.ssh/keys/id_ed25519 (SSH key for private repo)"
        echo "  3. Creating ~/.config/nix/nix.conf"
        echo "  4. Cloning the nix config repo with submodules"
        echo "  5. Decrypting the cache signing key"
        echo ""
        echo "Prerequisites:"
        echo "  - SSH access to the remote host"
        echo "  - Nix installed on the remote host"
        echo "  - Local ~/.age/age.pem and ~/.ssh/keys/id_ed25519 exist"
        exit 1
    fi

    # Parse host and port (format: host or host:port)
    if [[ "$INPUT" == *:* ]]; then
        REMOTE_HOST="''${INPUT%:*}"
        SSH_PORT="''${INPUT##*:}"
    else
        REMOTE_HOST="$INPUT"
        SSH_PORT="22"
    fi

    SSH_OPTS=(-p "$SSH_PORT")
    SCP_OPTS=(-P "$SSH_PORT")

    # Verify local prerequisites
    if [[ ! -f "$HOME/.age/age.pem" ]]; then
        log_error "Local ~/.age/age.pem not found"
        exit 1
    fi

    if [[ ! -f "$HOME/.ssh/keys/id_ed25519" ]]; then
        log_error "Local ~/.ssh/keys/id_ed25519 not found"
        exit 1
    fi

    PORT_INFO=""
    [[ "$SSH_PORT" != "22" ]] && PORT_INFO=" (port $SSH_PORT)"
    log_info "Setting up remote host: ''${BOLD}$REMOTE_HOST''${NC}$PORT_INFO"

    # Get remote home directory
    log_info "Detecting remote home directory..."
    REMOTE_HOME=$(ssh "''${SSH_OPTS[@]}" "$REMOTE_HOST" 'echo $HOME')
    log_success "Remote home: $REMOTE_HOME"

    # Create required directories on remote
    log_info "Creating directories on remote..."
    ssh "''${SSH_OPTS[@]}" "$REMOTE_HOST" "mkdir -p ~/.age ~/.ssh/keys ~/.config/nix"
    log_success "Directories created"

    # Copy age key
    log_info "Copying age key..."
    scp "''${SCP_OPTS[@]}" "$HOME/.age/age.pem" "$REMOTE_HOST:~/.age/age.pem"
    ssh "''${SSH_OPTS[@]}" "$REMOTE_HOST" "chmod 600 ~/.age/age.pem"
    log_success "Age key copied"

    # Copy SSH key
    log_info "Copying SSH key..."
    scp "''${SCP_OPTS[@]}" "$HOME/.ssh/keys/id_ed25519" "$REMOTE_HOST:~/.ssh/id_ed25519"
    ssh "''${SSH_OPTS[@]}" "$REMOTE_HOST" "chmod 600 ~/.ssh/id_ed25519"
    log_success "SSH key copied"

    ssh "''${SSH_OPTS[@]}" "$REMOTE_HOST" "ssh-keyscan github.com >> ~/.ssh/known_hosts"

    # Create nix.conf with dynamic path
    log_info "Creating nix.conf..."
    ssh "''${SSH_OPTS[@]}" "$REMOTE_HOST" "cat > ~/.config/nix/nix.conf" <<EOF
    experimental-features = nix-command flakes
    substituters = http://ncps.hyades.io:8501 https://nix-community.cachix.org https://cache.nixos.org
    trusted-public-keys = ncps.hyades.io:/02vviGNLGYhW28GFzmPFupnP6gZ4uDD4G3kRnXuutE= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
    secret-key-files = $REMOTE_HOME/.config/nix/config/private/cache-priv-key.pem
    EOF
    log_success "nix.conf created"

    # Clone the repo
    log_info "Cloning nix config repository..."
    ssh "''${SSH_OPTS[@]}" "$REMOTE_HOST" "git clone --recursive git@github.com:kamushadenes/nix.git ~/.config/nix/config/"
    log_success "Repository cloned"

    # Decrypt cache signing key
    #log_info "Decrypting cache signing key..."
    #ssh "''${SSH_OPTS[@]}" "$REMOTE_HOST" "${lib.getExe pkgs.age} -d -i ~/.age/age.pem ~/.config/nix/config/private/cache-priv-key.pem.age > ~/.config/nix/config/private/cache-priv-key.pem && chmod 600 ~/.config/nix/config/private/cache-priv-key.pem"
    #log_success "Cache key decrypted"

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
    happy-coder
    ccusage
    nix-remote-setup
    ;
}
