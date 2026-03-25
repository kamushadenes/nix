# Module Reference

This document provides a comprehensive catalog of all modules in this Nix
configuration. The system is organized into layers that separate user-level
configuration from system-level settings, allowing for high reusability across
different platforms and machine roles.

## Table of Contents

- [Home-Manager Modules](#home-manager-modules)
  - [AI Tools](#ai-tools)
  - [Core](#core)
  - [Development](#development)
  - [Editors](#editors)
  - [Infrastructure](#infrastructure)
  - [Shell](#shell)
  - [Security](#security)
  - [Utilities](#utilities)
  - [Media](#media)
  - [Sync](#sync)
- [Platform-Specific Home Modules](#platform-specific-home-modules)
  - [macOS](#macos)
  - [Linux](#linux)
- [Darwin System Modules](#darwin-system-modules)
- [NixOS System Modules](#nixos-system-modules)
- [Shared Modules](#shared-modules)
- [Role Composition](#role-composition)
- [Adding a New Module](#adding-a-new-module)

## Home-Manager Modules

These modules handle user-level configuration and are shared across all
platforms. They are located in the `home/common/` directory.

### AI Tools (home/common/ai/)

The AI tools category manages the configuration for various AI coding assistants
and their supporting infrastructure.

- `claude-code.nix`: Configures the Claude Code CLI with custom settings and
  integrated MCP servers. It uses the built-in home-manager module for settings
  and manages secrets via agenix.
- `opencode.nix`: Sets up the OpenCode environment with shared MCP server
  configurations. It handles secret substitution at activation time for secure
  API access.
- `codex-cli.nix`: Configures the OpenAI Codex CLI with MCP servers from the
  shared configuration. It uses agenix to manage the TOML configuration file
  containing sensitive tokens.
- `gemini-cli.nix`: Sets up the Google Gemini CLI with shared MCP
  configurations. It manages a JSON configuration file with secrets encrypted
  via agenix.
- `mcp-servers.nix`: Provides a unified and normalized configuration for Model
  Context Protocol servers. This module transforms a single definition into the
  specific formats required by different AI tools.
- `claude-code-permissions.nix`: Defines the auto-approved tools for Claude Code
  workflows. It organizes permissions by tool type to simplify maintenance and
  security auditing.
- `orchestrator.nix`: Handles the deployment of agent skills to the standard
  agentskills.io location. It auto-discovers skills from the resources directory
  and makes them available to all supported agents.
- `gsd-claude.nix`: Manages the Get Shit Done (GSD) framework files specifically
  for Claude Code. It deploys the framework to the local claude directory
  without requiring the npm installer.
- `gsd-opencode.nix`: Manages the Get Shit Done (GSD) framework files for the
  OpenCode environment. It ensures the framework is correctly deployed to the
  opencode configuration directory.
- `peon-ping.nix`: Provides voice notifications for AI coding agent events like
  session starts and completions. It uses an LCARS sound pack and manages
  installation via activation scripts.

### Core (home/common/core/)

Core modules provide the essential foundation for any machine, including version
control, secret management, and basic networking.

- `git.nix`: Configures Git with global ignore files, pre-commit hooks, and
  helper tools. It includes settings for delta, gh, and custom git aliases.
- `nix.nix`: Sets up the Nix environment with modern tools like nh, devbox, and
  nix-tree. It configures substituters and trusted public keys for the binary
  cache.
- `nix-minimal.nix`: Provides a stripped-down Nix configuration for service
  containers. It disables man pages and other non-essential features to reduce
  the closure size.
- `agenix.nix`: Integrates the agenix secret management system into
  home-manager. It ensures the agenix package is available and correctly
  configured for the host platform.
- `fonts.nix`: Configures system-wide font management and fontconfig settings.
  It enables font discovery and sets up default font aliases for the user
  session.
- `network.nix`: Installs a set of core networking utilities. This includes
  essential tools like curl, cloudflared, and other diagnostic packages.

### Development (home/common/dev/)

The development category contains modules for various programming languages and
specialized development environments.

- `go.nix`: Sets up a complete Go development environment. It includes the Go
  compiler, common tools, and a custom godoc-mcp server for AI-assisted
  documentation lookup.
- `node.nix`: Configures Node.js and Bun runtimes. It includes a custom TDD
  Guard tool for Linux and sets up common global packages.
- `python.nix`: Provides a Python environment with essential development tools.
  It configures the Python interpreter and common libraries used across
  projects.
- `java.nix`: Enables and configures the Java runtime environment. It sets up
  the JAVA_HOME environment variable and installs the default JDK.
- `clang.nix`: Installs C and C++ development tools. This includes the Clang
  compiler, autoconf, automake, and other build-essential packages.
- `clojure.nix`: Sets up the Clojure development environment. It includes
  babashka, the Clojure CLI, and other functional programming tools.
- `android.nix`: Configures the Android development environment. It sets up the
  necessary SDKs and tools for mobile application development.
- `embedded.nix`: Provides tools for embedded systems development. This includes
  avrdude, platformio, and other hardware-level programming utilities.
- `lazygit.nix`: Configures the Lazygit terminal UI for git. It includes custom
  keybindings and integration with the Catppuccin theme.
- `lazyworktree.nix`: Installs and configures a custom tool for managing git
  worktrees. It provides a streamlined interface for switching between different
  project branches.
- `worktrunk.nix`: Provides the Worktrunk CLI for advanced git worktree
  management. It is designed to work seamlessly with AI agent workflows.
- `mcphub.nix`: Configures the MCP Hub for managing multiple Model Context
  Protocol servers. It provides a central point for server discovery and
  configuration.
- `dev.nix`: A meta-module that groups common development utilities. It installs
  a collection of tools used across different programming languages.

### Editors (home/common/editors/)

This category manages the configuration for the primary text editors used in the
environment.

- `nvim.nix`: Configures Neovim using the LazyVim distribution. It includes a
  comprehensive set of plugins for development, AI integration, and UI
  enhancements.
- `emacs.nix`: Sets up Emacs with the Doom Emacs configuration. It provides a
  fast and modular Emacs environment tailored for developers.
- `vscode.nix`: Manages VS Code settings and extensions. It allows for a
  consistent editor experience even when using a GUI-based editor.

### Infrastructure (home/common/infra/)

Infrastructure modules provide tools for managing containers, clusters, and
cloud resources.

- `docker.nix`: Installs Docker client tools and buildx plugins. It ensures the
  user has the necessary tools to interact with Docker daemons.
- `kubernetes.nix`: Sets up a complete Kubernetes management toolkit. This
  includes kubectl, helm, k9s, and other cluster orchestration tools.
- `cloud.nix`: Configures command-line interfaces for major cloud providers. It
  includes awscli, gcloud, and other cloud management utilities.
- `iac.nix`: Provides Infrastructure as Code tools. This includes Terraform,
  Packer, and Infracost for managing and auditing infrastructure.
- `db.nix`: Installs various database clients and utilities. It includes sqlite,
  mycli, and other tools for interacting with different database engines.

### Shell (home/common/shell/)

The shell category handles the configuration of terminal shells, multiplexers,
and modern CLI utilities.

- `fish.nix`: Configures the Fish shell as the primary interactive shell. It
  includes custom functions, aliases, and integration with the shared shell
  configuration.
- `bash.nix`: Sets up the Bash shell with shared configuration. It ensures a
  consistent environment when Bash is used for scripting or as a fallback shell.
- `zsh.nix`: Configures the Zsh shell with shared settings. It provides a
  familiar environment for users who prefer Zsh over Fish.
- `starship.nix`: Sets up the Starship cross-shell prompt. It uses a custom
  theme that provides informative and visually appealing prompts across all
  supported shells.
- `tmux.nix`: Configures the Tmux terminal multiplexer. It includes custom
  keybindings, theme integration, and support for persistent terminal sessions.
- `kitty.nix`: Sets up the Kitty terminal emulator. It configures fonts, themes,
  and advanced terminal features for a high-performance terminal experience.
- `ghostty.nix`: Configures the Ghostty terminal emulator. It applies the
  Catppuccin theme and sets up terminal-specific features.
- `misc.nix`: Installs a wide range of modern CLI utilities. This includes tools
  like ripgrep, fd, fzf, bat, htop, jq, and eza.
- `misc-minimal.nix`: Provides a subset of essential CLI tools for minimal
  roles. It focuses on keeping the closure size small while providing the most
  important utilities.

### Security (home/common/security/)

Security modules handle encryption, signing, and security auditing tools.

- `gpg.nix`: Configures GnuPG for the user. It sets up the GPG agent and manages
  public keys and trust settings.
- `tools.nix`: Installs a collection of security scanning and auditing
  utilities. This includes tools for vulnerability research and system
  hardening.

### Utilities (home/common/utils/)

This category contains miscellaneous utility tools that don't fit into other
specific categories.

- `aichat.nix`: Configures the aichat CLI tool. It allows for quick interaction
  with various LLM providers directly from the terminal.
- `clipboard.nix`: Provides remote clipboard and URL opening support over SSH.
  It uses port forwarding to bridge the local and remote clipboards.
- `utils.nix`: Installs a variety of miscellaneous utility packages. This
  includes tools for file management, system monitoring, and general
  productivity.

### Media (home/common/media/)

- `media.nix`: Installs media processing and playback tools. This includes
  powerful utilities like ffmpeg, imagemagick, and yt-dlp.

### Sync (home/common/sync/)

- `mutagen.nix`: Configures Mutagen for high-performance file synchronization.
  It is used to keep project files in sync across different machines in a
  hub-and-spoke topology.

## Platform-Specific Home Modules

These modules handle configuration unique to specific operating systems.

### macOS (home/macos/)

- `aerospace.nix`: Configures the Aerospace tiling window manager for macOS. It
  defines layouts, keybindings, and workspace settings.
- `bettertouchtool.nix`: Manages BetterTouchTool presets. It allows for advanced
  input customization and automation on macOS.
- `sketchybar.nix`: Sets up the Sketchybar status bar. It includes a collection
  of custom plugins for monitoring system stats, battery, and network.

### Linux (home/linux/)

- `display.nix`: Configures Linux-specific display settings and window managers.
  It handles the setup of desktop environments and display servers.
- `security.nix`: Manages Linux-specific security settings. This includes
  configuration for polkit, firewalls, and other system-level security features.
- `systemd.nix`: Manages user-level systemd services. It ensures that
  environment variables and background tasks are correctly handled in the user
  session.
- `shell.nix`: Provides Linux-specific shell configurations. It includes
  terminal emulators and shell settings that are only relevant on Linux systems.

## Darwin System Modules

These modules configure system-level settings for macOS and are located in the
`darwin/` directory.

- `activation.nix`: Defines custom system activation scripts that run when the
  configuration is applied.
- `brew.nix`: Manages Homebrew installation and configuration. It handles taps,
  formulas, and casks while optimizing for disk space.
- `browser.nix`: Installs and configures web browsers via Homebrew casks. It
  ensures a consistent set of browsers is available on all Darwin machines.
- `db.nix`: Sets up database-related applications and tools at the system level.
- `dev.nix`: Installs system-level development tools. This includes
  virtualization tools like QEMU and other low-level utilities.
- `dock.nix`: Manages the macOS Dock layout. It allows for programmatic control
  over which applications are pinned to the Dock.
- `dropbox.nix`: Configures the Dropbox client at the system level.
- `finance.nix`: Installs financial management applications via Homebrew casks.
- `fonts.nix`: Manages system-wide fonts on macOS. It integrates with the shared
  font definitions used across the configuration.
- `imaging.nix`: Installs disk imaging and flashing tools like balenaEtcher.
- `ipfs.nix`: Enables and configures the IPFS system service on macOS.
- `login.nix`: Manages launchd agents that run at user login. It is used for
  background utilities that need to start automatically.
- `mas.nix`: Installs applications from the Mac App Store using the `mas` CLI.
- `media.nix`: Sets up system-level media players and processing tools.
- `meeting.nix`: Installs communication and meeting applications like Zoom or
  Microsoft Teams.
- `nix.nix`: Configures system-level Nix settings for Darwin. It includes shared
  documentation settings and Nix daemon configuration.
- `security.nix`: Sets up security tools and applications. This includes
  password managers and network analysis tools.
- `setapp.nix`: Installs the Setapp application manager via Homebrew.
- `settings.nix`: Configures a wide range of macOS system defaults. This
  includes keyboard, trackpad, Finder, and other UI preferences.
- `sharing.nix`: Manages macOS sharing settings. It controls services like
  screen sharing, file sharing, and remote login.
- `shells.nix`: Configures system-level shell enablement. It ensures that shells
  like Fish are recognized as valid login shells.
- `tiling.nix`: Sets up window tiling tools and their system-level dependencies.
- `users.nix`: Manages macOS user accounts and their associated permissions.
- `utils.nix`: Installs miscellaneous system utility applications and tools.

## NixOS System Modules

These modules configure system-level settings for NixOS and are located in the
`nixos/` directory.

- `audio.nix`: Configures PipeWire for high-quality audio on NixOS. It handles
  sound server settings and hardware compatibility.
- `browser.nix`: Installs system-wide browsers and related driver tools like
  chromedriver.
- `dev.nix`: Sets up system-level development environments and tools like the
  Arduino IDE.
- `display_gnome.nix`: Configures the GNOME desktop environment. It includes
  settings for dconf and other GNOME-specific components.
- `display_sway.nix`: Sets up the Sway tiling window manager. It handles
  security settings like polkit that are required for Sway to function
  correctly.
- `finance.nix`: Installs financial tools like Ledger Live at the system level.
- `fonts.nix`: Manages system-wide fonts on NixOS. It uses the shared font
  definitions to ensure consistency across platforms.
- `ipfs.nix`: Enables and configures the IPFS service on NixOS.
- `media.nix`: Installs system-level media processing tools like Audacity.
- `meeting.nix`: Sets up communication tools like Discord at the system level.
- `minimal.nix`: Provides a minimal system configuration for LXC containers. It
  focuses on providing SSH access and essential system services.
- `nix.nix`: Configures system-level Nix settings for NixOS. It includes shared
  documentation settings and Nix daemon configuration.
- `security.nix`: Handles system security, polkit, and firewall settings. It
  adapts its configuration based on the machine's role.
- `shells.nix`: Configures system-level shell enablement. It ensures that all
  configured shells are available for use.
- `users.nix`: Manages NixOS user accounts, groups, and SSH keys.
- `utils.nix`: Installs miscellaneous system utility packages like ClickUp.

## Shared Modules

Shared modules provide utilities and configurations used across all layers of
the system. They are located in the `shared/` directory.

- `helpers.nix`: Provides a collection of helper functions. This includes global
  variable definitions, theme helpers, and YAML/TOML conversion tools.
- `roles.nix`: Defines the role-based module composition system. It is the
  central point for determining which modules are included in each machine role.
- `shell-common.nix`: Contains shell functions and aliases shared across Fish,
  Zsh, and Bash. It handles the differences in shell syntax via separate script
  files.
- `build.nix`: Configures distributed builds. It allows machines to share build
  tasks over the network using the ssh-ng protocol.
- `cache.nix`: Sets up binary caches and post-build upload hooks. It ensures
  that build results are cached and shared across the infrastructure.
- `deploy.nix`: Manages node configuration for the custom deployment tool. It
  reads from a private JSON file to generate the deployment targets.
- `documentation.nix`: Configures cross-platform documentation settings. It
  ensures that man pages and other documentation are handled consistently.
- `fish-plugins.nix`: Defines a set of plugins for the Fish shell. It handles
  the fetching and installation of plugins from GitHub.
- `fonts-common.nix`: Provides shared font package definitions. It returns a
  list of font packages used by both Darwin and NixOS system modules.
- `overlays.nix`: Provides shared package overlays. This includes the Lix
  package overlay that replaces certain packages with their Lix equivalents.
- `packages.nix`: Defines custom packages and package overrides. It is used for
  tools that are not available in the standard nixpkgs.
- `shells.nix`: Handles cross-platform shell enablement. It ensures that shells
  are correctly configured at the system level on both Darwin and NixOS.
- `themes.nix`: Defines the Catppuccin Macchiato theme colors and variants. It
  provides a single source of truth for the system's visual style.
- `age-home.nix`: Provides a patched version of the agenix home-manager module.
  It fixes issues with stale generation directories that can cause activation
  loops.

## Role Composition

Roles control which home-manager modules are imported for each machine. This
system allows for a tailored experience based on the machine's purpose. The
definitions are managed in `shared/roles.nix`.

### Module Groups

The role system is built from several module groups:

```nix
# Core minimal - just disabled man pages
coreMinimal = [ ../home/common/core/nix-minimal.nix ];

# Minimal core - nix tools (nh, devbox, nix-tree, etc.)
minimalCore = [ ../home/common/core/nix.nix ];

# Full core - adds agenix, fonts, git, network, ssh
fullCore = minimalCore ++ [
  ../home/common/core/agenix.nix
  ../home/common/core/fonts.nix
  ../home/common/core/git.nix
  ../home/common/core/network.nix
  "${private}/home/common/core/ssh.nix"
];

# Shell minimal - essential shell config with core CLI tools
shellMinimal = [
  ../home/common/shell/bash.nix
  ../home/common/shell/fish.nix
  ../home/common/shell/zsh.nix
  ../home/common/shell/misc-minimal.nix
  ../home/common/shell/starship.nix
  ../home/common/shell/tmux.nix
];

# Shell modules - full CLI configuration
shellAll = [
  ../home/common/shell/bash.nix
  ../home/common/shell/fish.nix
  ../home/common/shell/zsh.nix
  ../home/common/shell/misc.nix
  ../home/common/shell/starship.nix
  ../home/common/shell/tmux.nix
];
```

### Role Definitions

The three primary roles are composed as follows:

- **Workstation**: Full GUI experience with all development tools.
  - `base` (fullCore + shellAll + security)
  - `ai`, `dev`, `editors`, `infra`, `utils`, `sync`, `media`, `guiShell`
  - Platform-specific GUI tools (macOS or Linux Desktop)

- **Headless**: CLI-only development environment.
  - `base` (fullCore + shellAll + security)
  - `ai`, `dev`, `editors`, `infra`, `utils`, `sync`
  - Linux CLI tools (if on Linux)

- **Minimal**: Familiar shell environment for service containers.
  - `coreMinimal`
  - `shellMinimal`
  - Linux minimal systemd settings (if on Linux)

## Adding a New Module

Follow these steps to add a new module to the configuration.

1. **Create the file**: Add your new `.nix` file to the appropriate directory.
   For example, a new utility would go in `home/common/utils/my-tool.nix`.
2. **Define the module**: Use the standard Nix module format. Ensure you handle
   platform differences if necessary.
   ```nix
   { pkgs, ... }:
   {
     home.packages = [ pkgs.my-tool ];
   }
   ```
3. **Register the module**: Add the file path to the relevant module group in
   `shared/roles.nix`. If it's a general utility, add it to the `utils` group.
4. **Commit the file**: Nix flakes only see files that are tracked by git. You
   must stage the new file before it can be used in a build.
   ```bash
   git add home/common/utils/my-tool.nix
   ```
5. **Rebuild**: Apply the changes to your system using the `rebuild` command.
   ```bash
   rebuild
   ```
