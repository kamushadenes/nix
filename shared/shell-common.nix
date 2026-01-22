# Shell configuration shared across fish, zsh, and bash
{
  config,
  lib,
  pkgs,
  osConfig,
  private,
  packages,
  ...
}:
let
  # Resource files directory
  resourcesDir = ./resources/shell;

  # Import account configuration for multi-account support
  accountsConfig = import ../home/common/ai/claude-accounts.nix { inherit config lib; };

  # Import deployment configuration for rebuild tool
  deployConfig = import ./deploy.nix { inherit lib pkgs private; };

  # SSH keys to be loaded (only if agenix is enabled)
  sshKeys =
    if config.age.secrets ? "id_ed25519.age"
    then [ config.age.secrets."id_ed25519.age".path ]
    else [ ];

  # Cache key paths for rebuild function
  cacheKeyPath = "$HOME/.config/nix/config/private/cache-priv-key.pem";
  cacheKeyAgePath = "$HOME/.config/nix/config/private/cache-priv-key.pem.age";
  ageIdentity = "$HOME/.age/age.pem";

  # Substitutions for deploy.py script template
  deploySubst = {
    "@nodeConfigJson@" = deployConfig.configJson;
    "@cacheKeyPath@" = cacheKeyPath;
    "@cacheKeyAgePath@" = cacheKeyAgePath;
    "@ageIdentity@" = ageIdentity;
    "@ageBin@" = "${pkgs.age}/bin/age";
    "@nixRemoteSetup@" = "${packages.nix-remote-setup}/bin/nix-remote-setup";
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
    claudeAttach = builtins.readFile "${resourcesDir}/ca.sh";
    rgaFzf = builtins.readFile "${resourcesDir}/rga-fzf.sh";
    flushdns = builtins.readFile "${resourcesDir}/flushdns.sh";
    help = builtins.readFile "${resourcesDir}/help.sh";
  };

  # Read script files - fish versions (use fish syntax: set, $argv, end)
  fishScripts = {
    mkcd = builtins.readFile "${resourcesDir}/mkcd.fish";
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
    c = applySubst cScriptSubst (builtins.readFile "${resourcesDir}/claude-tmux.sh");
    # Rebuild script - Python deployment tool with parallel execution and tag-based filtering
    rebuild = applySubst deploySubst (builtins.readFile ./resources/deploy.py);
  };

  # Common PATH additions
  pathAdditions = [
    "${config.home.homeDirectory}/.npm-global/bin"
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

  # On NixOS, /run/wrappers/bin must come first for setuid binaries (sudo, etc.)
  wrappersPath = lib.optionalString (!pkgs.stdenv.isDarwin) ''
    export PATH="/run/wrappers/bin:$PATH"
  '';

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

        # Note: 'c' and 'rebuild' are now standalone scripts in PATH (see standaloneScripts)

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

    # Convert bash-style ${VAR} to fish-style $VAR for agenix paths
    sshKeyLoading =
      let
        bashToFish = str: builtins.replaceStrings [ "\${" "}" ] [ "$" "" ] str;
      in
      lib.concatMapStringsSep "\n" (key: "test -f ${bashToFish key} && ssh-add -q ${bashToFish key}") sshKeys;

    pathSetup = mkPathSetup pathFormatters.fish;

    ghosttyIntegration = lib.optionalString pkgs.stdenv.isDarwin ''
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
    # Note: 'c' and 'rebuild' are now standalone scripts in PATH (see standaloneScripts)
    functions = ''
      mkcd() { ${bashScripts.mkcd} }
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
  bash.pathSetup = wrappersPath + mkPathSetup pathFormatters.bash;

  # Path setup for zsh (path+=)
  zsh.pathSetup = wrappersPath + mkPathSetup pathFormatters.zsh;
}
