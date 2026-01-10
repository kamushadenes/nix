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

  # Script to prepare a remote machine for this nix configuration
  # Copies age key, SSH key, creates nix.conf, clones repos, and provides activation instructions
  nix-remote-setup = pkgs.writeScriptBin "nix-remote-setup" ''
    #!${lib.getExe pkgs.bash}
    set -euo pipefail

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color

    log_info() { echo -e "''${BLUE}[INFO]''${NC} $1"; }
    log_success() { echo -e "''${GREEN}[OK]''${NC} $1"; }
    log_warn() { echo -e "''${YELLOW}[WARN]''${NC} $1"; }
    log_error() { echo -e "''${RED}[ERROR]''${NC} $1"; }

    REMOTE_HOST="''${1:-}"

    if [[ -z "$REMOTE_HOST" ]]; then
        echo "Usage: nix-remote-setup <user@host>"
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

    # Verify local prerequisites
    if [[ ! -f "$HOME/.age/age.pem" ]]; then
        log_error "Local ~/.age/age.pem not found"
        exit 1
    fi

    if [[ ! -f "$HOME/.ssh/keys/id_ed25519" ]]; then
        log_error "Local ~/.ssh/keys/id_ed25519 not found"
        exit 1
    fi

    log_info "Setting up remote host: $REMOTE_HOST"

    # Get remote home directory
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
    scp "$HOME/.ssh/keys/id_ed25519" "$REMOTE_HOST:~/.ssh/keys/id_ed25519"
    ssh "$REMOTE_HOST" "chmod 600 ~/.ssh/keys/id_ed25519"
    log_success "SSH key copied"

    # Create nix.conf with dynamic path
    log_info "Creating nix.conf..."
    ssh "$REMOTE_HOST" "cat > ~/.config/nix/nix.conf" <<EOF
    experimental-features = nix-command flakes
    substituters = http://ncps.hyades.io:8501 https://nix-community.cachix.org https://cache.nixos.org
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
    ssh "$REMOTE_HOST" "${lib.getExe pkgs.age} -d -i ~/.age/age.pem ~/.config/nix/config/private/cache-priv-key.pem.age > ~/.config/nix/config/private/cache-priv-key.pem && chmod 600 ~/.config/nix/config/private/cache-priv-key.pem"
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
  inherit gitSquash colorScript lazyworktree happy-coder nix-remote-setup;
}
