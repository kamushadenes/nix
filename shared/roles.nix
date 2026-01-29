# Role-based module composition
#
# Roles control which home-manager modules are imported for each machine.
# This enables headless servers to skip GUI modules while maintaining
# full dev tooling, and service containers to have a familiar shell
# environment without development overhead.
#
# Role hierarchy:
#   workstation - Full GUI experience with all dev tools
#   headless    - Full dev tooling, CLI only (no GUI apps)
#   minimal     - Familiar shell environment only (for service containers)
#
# Usage in flake.nix:
#   mkDarwinHost { machine = "..."; role = "workstation"; }
#   mkNixosHost { machine = "..."; role = "headless"; }
#   mkProxmoxHost { machine = "..."; role = "minimal"; }
#
{ lib, private }:
let
  # ============================================================
  # Module Groups - Building blocks for role composition
  # ============================================================

  # Core minimal - just disabled man pages (for service containers)
  coreMinimal = [
    ../home/common/core/nix-minimal.nix
  ];

  # Minimal core - nix tools (nh, devbox, nix-tree, etc.)
  minimalCore = [
    ../home/common/core/nix.nix
  ];

  # Full core - adds agenix, fonts, git, network, ssh
  fullCore = minimalCore ++ [
    ../home/common/core/agenix.nix
    ../home/common/core/fonts.nix
    ../home/common/core/git.nix
    ../home/common/core/network.nix
    "${private}/home/common/core/ssh.nix"
  ];

  # Shell minimal - essential shell config with core CLI tools (for service containers)
  # Includes: fish/bash/zsh, starship, tmux, ripgrep, fd, bat, eza, fzf, nh
  # Excludes: atuin, broot, yazi, dust, difftastic, and other heavy Rust tools
  shellMinimal = [
    ../home/common/shell/bash.nix
    ../home/common/shell/fish.nix
    ../home/common/shell/zsh.nix
    ../home/common/shell/misc-minimal.nix # Essential tools only (ripgrep, fd, bat, eza, fzf)
    ../home/common/shell/starship.nix
    ../home/common/shell/tmux.nix
  ];

  # Shell modules - CLI configuration (no GUI terminals)
  # Provides: fish/bash/zsh with starship, tmux, modern CLI tools
  shellAll = [
    ../home/common/shell/bash.nix
    ../home/common/shell/fish.nix
    ../home/common/shell/zsh.nix
    ../home/common/shell/misc.nix # ripgrep, fd, fzf, bat, htop, jq, eza, etc.
    ../home/common/shell/starship.nix
    ../home/common/shell/tmux.nix
  ];

  # Security modules - GPG, security scanning tools
  security = [
    ../home/common/security/gpg.nix
    ../home/common/security/tools.nix
  ];

  # Base modules for workstation/headless roles (backwards compat)
  base = fullCore ++ shellAll ++ security;

  # AI tools - Claude, orchestrator, etc.
  # Note: moltbot removed - now runs as system service on moltbot LXC
  ai = [
    ../home/common/ai/claude-code.nix
    ../home/common/ai/codex-cli.nix
    ../home/common/ai/gemini-cli.nix
    ../home/common/ai/orchestrator.nix
  ];

  # Development tools
  dev = [
    ../home/common/dev/android.nix
    ../home/common/dev/clang.nix
    ../home/common/dev/clojure.nix
    ../home/common/dev/dev.nix
    ../home/common/dev/embedded.nix
    ../home/common/dev/go.nix
    ../home/common/dev/java.nix
    ../home/common/dev/lazygit.nix
    ../home/common/dev/lazyworktree.nix
    ../home/common/dev/node.nix
    ../home/common/dev/python.nix
    ../home/common/dev/worktrunk.nix
  ];

  # All editors (nvim, emacs, vscode - all work headlessly)
  editors = [
    ../home/common/editors/emacs.nix
    ../home/common/editors/nvim.nix
  ];

  # Infrastructure tools
  infra = [
    ../home/common/infra/cloud.nix
    ../home/common/infra/db.nix
    ../home/common/infra/docker.nix
    ../home/common/infra/iac.nix
    ../home/common/infra/kubernetes.nix
  ];

  # Utilities
  utils = [
    ../home/common/utils/aichat.nix
    ../home/common/utils/clipboard.nix
    ../home/common/utils/utils.nix
  ];

  # File sync (Mutagen)
  sync = [
    ../home/common/sync/mutagen.nix
  ];

  # Media tools (workstation only)
  media = [
    ../home/common/media/media.nix
  ];

  # GUI shell tools (workstation only - terminals with GUI)
  guiShell = [
    ../home/common/shell/ghostty.nix
    ../home/common/shell/kitty.nix
  ];

  # macOS-specific (workstation + darwin only)
  macos = [
    ../home/macos/aerospace.nix
    ../home/macos/bettertouchtool.nix
    ../home/macos/sketchybar.nix
  ];

  # Linux display/desktop (workstation + linux only)
  linuxDesktop = [
    ../home/linux/display.nix
  ];

  # Linux CLI (headless + linux)
  linuxCli = [
    ../home/linux/security.nix
    ../home/linux/shell.nix
    ../home/linux/systemd.nix
  ];

  # Linux minimal - just systemd for user session variables
  linuxMinimal = [
    ../home/linux/systemd.nix
  ];
in
{
  # Export module groups for documentation/debugging
  inherit base ai dev editors infra utils sync media guiShell macos linuxDesktop linuxCli;
  inherit coreMinimal minimalCore fullCore shellMinimal shellAll security linuxMinimal;

  # Compose modules based on role and platform
  # platform should be "darwin" or "linux"
  mkRoleModules =
    { role, platform }:
    let
      isDarwin = platform == "darwin" || lib.hasPrefix "aarch64-darwin" platform || lib.hasPrefix "x86_64-darwin" platform;
      isLinux = platform == "linux" || lib.hasPrefix "x86_64-linux" platform || lib.hasPrefix "aarch64-linux" platform;

      groups = {
        # Full workstation with all GUI apps
        workstation =
          base
          ++ ai
          ++ dev
          ++ editors
          ++ infra
          ++ utils
          ++ sync
          ++ media
          ++ guiShell
          ++ lib.optionals isDarwin macos
          ++ lib.optionals isLinux (linuxDesktop ++ linuxCli);

        # Headless server - CLI only, no GUI apps
        headless =
          base
          ++ ai
          ++ dev
          ++ editors
          ++ infra
          ++ utils
          ++ sync
          ++ lib.optionals isLinux linuxCli;

        # Minimal - familiar shell environment only
        # For service containers and simple machines
        # Includes: shells (fish/bash/zsh), starship, tmux, essential CLI tools (rg, fd, bat, eza, fzf, nh)
        # Excludes: agenix, fonts, git, SSH client config, security tools, dev tools
        # Excludes: heavy CLI tools (atuin, broot, yazi, dust, difftastic, etc.)
        minimal =
          coreMinimal
          ++ shellMinimal
          ++ lib.optionals isLinux linuxMinimal;
      };
    in
    groups.${role} or (throw "Unknown role: ${role}. Valid roles: workstation, headless, minimal");
}
