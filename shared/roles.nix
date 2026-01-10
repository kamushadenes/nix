# Role-based module composition
#
# Roles control which home-manager modules are imported for each machine.
# This enables headless servers to skip GUI modules while maintaining
# full dev tooling.
#
# Usage in flake.nix:
#   mkDarwinHost { machine = "..."; role = "workstation"; }
#   mkNixosHost { machine = "..."; role = "headless"; }
#
{ lib, private }:
let
  # Base modules included in ALL roles
  base = [
    # Core
    ../home/common/core/agenix.nix
    ../home/common/core/fonts.nix
    ../home/common/core/git.nix
    ../home/common/core/network.nix
    ../home/common/core/nix.nix
    "${private}/home/common/core/ssh.nix"

    # Shell (CLI only - no GUI terminals)
    ../home/common/shell/bash.nix
    ../home/common/shell/fish.nix
    ../home/common/shell/zsh.nix
    ../home/common/shell/misc.nix
    ../home/common/shell/starship.nix
    ../home/common/shell/tmux.nix

    # Security
    ../home/common/security/gpg.nix
    ../home/common/security/tools.nix
  ];

  # AI tools - Claude, orchestrator, etc.
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
    ../home/common/utils/utils.nix
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

  # Private/work-specific modules
  altinity = [
    "${private}/home/altinity/clickhouse.nix"
    "${private}/home/altinity/cloud.nix"
    "${private}/home/altinity/utils.nix"
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
in
{
  # Export module groups for documentation/debugging
  inherit base ai dev editors infra utils media guiShell altinity macos linuxDesktop linuxCli;

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
          ++ media
          ++ guiShell
          ++ altinity
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
          ++ altinity
          ++ lib.optionals isLinux linuxCli;

        # Minimal - just shell and git
        minimal = base;
      };
    in
    groups.${role} or (throw "Unknown role: ${role}. Valid roles: workstation, headless, minimal");
}
