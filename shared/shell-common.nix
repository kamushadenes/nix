# Shell configuration shared across fish, zsh, and bash
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  # Resource files directory
  resourcesDir = ./resources/shell;

  # Import account configuration for multi-account support
  accountsConfig = import ../home/common/ai/claude-accounts.nix { inherit config lib; };

  # SSH keys to be loaded
  sshKeys = [ config.age.secrets."id_ed25519.age".path ];

  # Cache key paths for rebuild function
  cacheKeyPath = "$HOME/.config/nix/config/private/cache-priv-key.pem";
  cacheKeyAgePath = "$HOME/.config/nix/config/private/cache-priv-key.pem.age";
  ageIdentity = "$HOME/.age/age.pem";

  # Platform-specific nh command
  nhCommand =
    if pkgs.stdenv.isDarwin then
      ''nh darwin switch --impure -H $(hostname -s | sed 's/.local//g')''
    else
      ''nh os switch --impure -H $(hostname -s | sed 's/.local//g')'';

  # Substitutions for rebuild script template
  rebuildSubst = {
    "@cacheKeyPath@" = cacheKeyPath;
    "@cacheKeyAgePath@" = cacheKeyAgePath;
    "@ageIdentity@" = ageIdentity;
    "@ageBin@" = "${pkgs.age}/bin/age";
    "@nhCommand@" = nhCommand;
  };

  # Helper to apply substitutions to a string
  applySubst = subst: str: builtins.foldl' (s: name: builtins.replaceStrings [ name ] [ subst.${name} ] s) str (builtins.attrNames subst);

  # Substitutions for c script (Claude workspace manager with multi-account support)
  cScriptSubst = {
    "@ACCOUNT_PATTERNS@" = accountsConfig.allAccountPatternVars;
    "@ACCOUNT_DETECTION_LOGIC@" = accountsConfig.allAccountDetectionLogic;
  };

  # Read script files - bash/zsh versions (use POSIX syntax where possible)
  bashScripts = {
    mkcd = builtins.readFile "${resourcesDir}/mkcd.sh";
    rebuild = applySubst rebuildSubst (builtins.readFile "${resourcesDir}/rebuild.sh");
    claudeAttach = builtins.readFile "${resourcesDir}/ca.sh";
    rgaFzf = builtins.readFile "${resourcesDir}/rga-fzf.sh";
    flushdns = builtins.readFile "${resourcesDir}/flushdns.sh";
    help = builtins.readFile "${resourcesDir}/help.sh";
  };

  # Read script files - fish versions (use fish syntax: set, $argv, end)
  fishScripts = {
    mkcd = builtins.readFile "${resourcesDir}/mkcd.fish";
    rebuild = applySubst rebuildSubst (builtins.readFile "${resourcesDir}/rebuild.fish");
    claudeAttach = builtins.readFile "${resourcesDir}/ca.fish";
    rgaFzf = builtins.readFile "${resourcesDir}/rga-fzf.fish";
    flushdns = builtins.readFile "${resourcesDir}/flushdns.sh"; # Simple command, works in fish
    help = builtins.readFile "${resourcesDir}/help.fish";
    # Fish-only (uses fish-specific array slicing syntax)
    addGoBuildTags = builtins.readFile "${resourcesDir}/add-go-build-tags.fish";
  };

  # Standalone scripts (installed to PATH, not shell functions)
  # These are processed with substitutions and return content (not paths)
  standaloneScripts = {
    # Claude Code workspace manager - bash script with multi-account support
    # Returns processed content with account patterns substituted
    c = applySubst cScriptSubst (builtins.readFile "${resourcesDir}/claude-tmux.sh");
  };

  # Common PATH additions
  pathAdditions = [
    "${config.home.homeDirectory}/.cargo/bin"
    "${config.home.homeDirectory}/.config/emacs/bin"
    "${config.home.homeDirectory}/.krew/bin"
    "${config.home.homeDirectory}/.config/composer/vendor/bin"
    "${config.home.homeDirectory}/.orbstack/bin"
    "${config.home.homeDirectory}/go/bin"
  ];

  # Factory for generating path setup commands per shell
  mkPathSetup = formatFn: lib.concatMapStringsSep "\n" formatFn pathAdditions;

  pathFormatters = {
    fish = path: "fish_add_path -a '${path}'";
    bash = path: ''export PATH="$PATH:${path}"'';
    zsh = path: ''path+=("${path}")'';
  };

  # Ghostty resources directory
  ghosttyResourcesDir = "/Applications/Ghostty.app/Contents/Resources/ghostty";

  # Check if package is in home.packages
  hasPackage = pkg: builtins.elem pkg config.home.packages;

in
{
  inherit sshKeys pathAdditions ghosttyResourcesDir hasPackage standaloneScripts;

  # Common aliases (shell-agnostic)
  aliases = lib.mkMerge [
    {
      unlock-gpg = "rm -f ~/.gnupg/public-keys.d/pubring.db.lock";
      renice-baldur = "sudo renice -n -20 -p $(pgrep -f Baldur)";
      # Unlock aether's LUKS encryption via initrd SSH
      aether-unlock = "ssh aether-initrd cryptsetup-askpass";
    }
    (lib.mkIf config.programs.bat.enable {
      cat = "bat -p";
      man = "batman";
    })
    (lib.mkIf config.programs.broot.enable { tree = "broot"; })
    (lib.mkIf config.programs.eza.enable {
      ls = "eza --icons -F -H --group-directories-first --git";
    })
    (lib.mkIf config.programs.kitty.enable {
      ssh = "kitten ssh";
      sudo = ''sudo TERMINFO="$TERMINFO"'';
    })
    # Modern CLI tool aliases
    (lib.mkIf (hasPackage pkgs.doggo) { dig = "doggo"; })
    (lib.mkIf (hasPackage pkgs.gping) { ping = "gping"; })
    (lib.mkIf (hasPackage pkgs.viddy) { watch = "viddy"; })
  ];

  # Fish-specific definitions
  fish = {
    functions = lib.mkMerge [
      {
        mkcd.body = fishScripts.mkcd;
        fish_greeting.body = "";

        rebuild = {
          description = "Rebuild nix configuration (decrypts cache key if needed)";
          body = fishScripts.rebuild;
        };

        # Note: 'c' is now a standalone script in PATH (see standaloneScripts)

        ca = {
          description = "Attach to existing tmux session via fzf selection";
          body = fishScripts.claudeAttach;
        };

        add_go_build_tags = {
          description = "Adds a custom Go build constraint to the beginning of .go files recursively.";
          body = fishScripts.addGoBuildTags;
        };

        rga-fzf.body = fishScripts.rgaFzf;
      }

      (lib.mkIf pkgs.stdenv.isDarwin {
        flushdns.body = fishScripts.flushdns;
      })

      (lib.mkIf config.programs.bat.enable {
        help.body = fishScripts.help;
      })
    ];

    sshKeyLoading = lib.concatMapStringsSep "\n" (key: "test -f ${key} && ssh-add -q ${key}") sshKeys;

    pathSetup = mkPathSetup pathFormatters.fish;

    ghosttyIntegration = ''
      # Set GHOSTTY_RESOURCES_DIR if not set
      if test -z "$GHOSTTY_RESOURCES_DIR"
          set -x GHOSTTY_RESOURCES_DIR "${ghosttyResourcesDir}"
      end

      _evalcache cat "$GHOSTTY_RESOURCES_DIR"/shell-integration/fish/vendor_conf.d/ghostty-shell-integration.fish
    '';

    homebrewInit = lib.optionalString pkgs.stdenv.isDarwin "_evalcache ${osConfig.homebrew.brewPrefix}/brew shellenv";
  };

  # Bash/Zsh shared definitions
  bashZsh = {
    # Note: 'c' is now a standalone script in PATH (see standaloneScripts)
    functions = ''
      mkcd() { ${bashScripts.mkcd} }
      rebuild() { ${bashScripts.rebuild} }
      ca() { ${bashScripts.claudeAttach} }
      rga-fzf() { ${bashScripts.rgaFzf} }
    '';

    flushdns = lib.optionalString pkgs.stdenv.isDarwin ''
      flushdns() { ${bashScripts.flushdns} }
    '';

    help = lib.optionalString config.programs.bat.enable ''
      help() { ${bashScripts.help} }
    '';

    sshKeyLoading = lib.concatMapStringsSep "\n" (
      key: ''test -f "${key}" && ssh-add -q "${key}"''
    ) sshKeys;

    ghosttyIntegration = {
      zsh = ''
        if test -z "$GHOSTTY_RESOURCES_DIR"; then
          export GHOSTTY_RESOURCES_DIR="${ghosttyResourcesDir}"
        fi
        if test -f "$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"; then
          source "$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
        fi
      '';

      bash = ''
        if test -z "$GHOSTTY_RESOURCES_DIR"; then
          export GHOSTTY_RESOURCES_DIR="${ghosttyResourcesDir}"
        fi
        if test -f "$GHOSTTY_RESOURCES_DIR/shell-integration/bash/ghostty.bash"; then
          source "$GHOSTTY_RESOURCES_DIR/shell-integration/bash/ghostty.bash"
        fi
      '';
    };

    homebrewInit = lib.optionalString pkgs.stdenv.isDarwin ''
      eval "$(${osConfig.homebrew.brewPrefix}/brew shellenv)"
    '';
  };

  # Path setup for bash (export PATH)
  bash.pathSetup = mkPathSetup pathFormatters.bash;

  # Path setup for zsh (path+=)
  zsh.pathSetup = mkPathSetup pathFormatters.zsh;
}
