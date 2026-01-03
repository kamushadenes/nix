{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  ########################################
  #                                      #
  # 1Password Path                       #
  #                                      #
  ########################################
  opBinPath = lib.getExe pkgs._1password-cli;

  ########################################
  #                                      #
  # YAML Functions                       #
  #                                      #
  ########################################
  fromYAML =
    yaml:
    builtins.fromJSON (
      builtins.readFile (
        pkgs.runCommand "from-yaml"
          {
            inherit yaml;
            allowSubstitutes = false;
            preferLocalBuild = true;
          }
          ''
            ${lib.getExe' pkgs.remarshal "remarshal"} -if yaml -i <(echo "$yaml") -of json -o $out
          ''
      )
    );

  readYAML = path: fromYAML (builtins.readFile path);

  ########################################
  #                                      #
  # TOML Functions                       #
  #                                      #
  ########################################
  toTOML =
    obj:
    let
      json = builtins.toJSON obj;
    in
    builtins.readFile (
      pkgs.runCommand "to-toml"
        {
          inherit json;
          allowSubstitutes = false;
          preferLocalBuild = true;
        }
        ''
          ${lib.getExe' pkgs.remarshal "remarshal"} -if json -i <(echo "$json") -of toml -o $out
        ''
    );

  ########################################
  #                                      #
  # Global Variables                     #
  #                                      #
  ########################################

  # Factory for generating variable exports in different shell formats
  mkVarExports = formatFn: vars:
    lib.concatMapStringsSep "\n" (var: formatFn var vars.${var}) (lib.attrNames vars);

  globalVariables = {
    base = {
      DOOMDIR = "${config.xdg.configHome}/doom";
      EMACSDIR = "${config.xdg.configHome}/emacs";
      DOOMLOCALDIR = "${config.xdg.dataHome}/doom";
      DOOMPROFILELOADFILE = "${config.xdg.stateHome}/doom-profiles-load.el";

      NIX_HM_PROFILE = config.home.profileDirectory;

      OP_BIN_PATH = opBinPath;

      # Vim is better for quick edits
      EDITOR = "nvim";

      NH_FLAKE = "${config.home.homeDirectory}/.config/nix/config/?submodules=1";
      DARWIN_USER_TEMP_DIR = lib.optionals pkgs.stdenv.isDarwin ''$(${lib.getExe' pkgs.coreutils "printf"} '%s' "$(${lib.getExe pkgs.getconf} DARWIN_USER_TEMP_DIR)" | ${lib.getExe' pkgs.coreutils "tr"} -d "\n")'';

      # Work around https://github.com/Homebrew/brew/issues/13219
      HOMEBREW_SSH_CONFIG_PATH = "${config.xdg.configHome}/ssh/brew_config";

      # Work around https://github.com/sharkdp/bat/issues/2578
      LESSUTFCHARDEF = "E000-F8FF:p,F0000-FFFFD:p,100000-10FFFD:p";
    };

    launchctl = mkVarExports (name: value: ''run /bin/launchctl setenv ${name} "${value}"'') globalVariables.base;
    shell = mkVarExports (name: value: ''export ${name}="${value}"'') globalVariables.base;
    fishShell = mkVarExports (name: value: ''set -x ${name} "${value}"'') globalVariables.base;
  };

  ########################################
  #                                      #
  # String Substitution Helper           #
  #                                      #
  ########################################

  # Apply named substitutions to a string (e.g., "@placeholder@" -> value)
  applySubst = subst: str:
    builtins.foldl'
      (s: name: builtins.replaceStrings [ name ] [ subst.${name} ] s)
      str
      (builtins.attrNames subst);

  ########################################
  #                                      #
  # Shell Integration Helpers            #
  #                                      #
  ########################################

  # Standard shell integrations (all shells enabled based on their enable state)
  shellIntegrations = {
    enableBashIntegration = config.programs.bash.enable;
    enableZshIntegration = config.programs.zsh.enable;
    enableFishIntegration = config.programs.fish.enable;
  };

  # Shell integrations with Fish disabled (for evalcache programs)
  shellIntegrationsNoFish = {
    enableBashIntegration = config.programs.bash.enable;
    enableZshIntegration = config.programs.zsh.enable;
    enableFishIntegration = false;
  };

  # Shell integrations for programs that only have bash/zsh (no fish option)
  shellIntegrationsBashZsh = {
    enableBashIntegration = config.programs.bash.enable;
    enableZshIntegration = config.programs.zsh.enable;
  };

  ########################################
  #                                      #
  # Theme Configuration                  #
  #                                      #
  ########################################

  theme = {
    name = "catppuccin";
    variant = "macchiato";

    # Pre-computed variants for different naming conventions
    variants = {
      underscore = "catppuccin_macchiato"; # btop, starship
      hyphen = "catppuccin-macchiato"; # ghostty, git
      titleSpace = "Catppuccin Macchiato"; # bat
      titleHyphen = "Catppuccin-Macchiato"; # kitty
      variantOnly = "macchiato"; # yazi, starship toml
    };
  };

  ########################################
  #                                      #
  # Email Helper Functions               #
  #                                      #
  ########################################

  mkEmail = user: domain: "${user}@${domain}";

  ########################################
  #                                      #
  # Git Helper Functions                 #
  #                                      #
  ########################################

  mkConditionalGithubIncludes =
    org: contents:
    let
      lowercase = lib.strings.toLower org;
    in
    [
      {
        condition = "hasconfig:remote.*.url:https://github.com/${org}/**";
        contents = contents;
      }

      {
        condition = "hasconfig:remote.*.url:git@github.com:${org}/**";
        contents = contents;
      }
    ]
    ++ lib.optionals (lowercase != org) [

      {
        condition = "hasconfig:remote.*.url:https://github.com/${lowercase}/**";
        contents = contents;
      }

      {
        condition = "hasconfig:remote.*.url:git@github.com:${lowercase}/**";
        contents = contents;
      }
    ];

  ########################################
  #                                      #
  # Fish Configuration Functions         #
  #                                      #
  ########################################

  fishProfilesPath =
    let
      dquote = str: "\"" + str + "\"";

      makeBinPathList = map (path: path + "/bin");
    in
    ''
      fish_add_path --move --prepend --path ${
        lib.concatMapStringsSep " " dquote (makeBinPathList osConfig.environment.profiles)
      }
      set fish_user_paths $fish_user_paths
    '';

  ########################################
  #                                      #
  # Kitty Configuration Functions        #
  #                                      #
  ########################################

  kittyProfilesPath =
    let
      makeBinPathList = map (path: path + "/bin");
    in
    lib.concatMapStringsSep "\n" (path: ''
      exe_search_path ${
        builtins.replaceStrings
          [
            "$HOME"
            "$USER"
          ]
          [
            config.home.homeDirectory
            osConfig.users.users.kamushadenes.name
          ]
          path
      }
    '') (makeBinPathList osConfig.environment.profiles);

  ########################################
  #                                      #
  # Agenix Helper Functions              #
  #                                      #
  ########################################

  mkAgenixPathSubst =
    path:
    if pkgs.stdenv.isDarwin then
      "\${DARWIN_USER_TEMP_DIR}${lib.concatStrings (lib.strings.match ".*\)(.*)" (builtins.toString path))}"
    else
      "\${XDG_RUNTIME_DIR}${lib.concatStrings (lib.strings.match ".[A-Z_]+\(.*\)" (builtins.toString path))}";

in
{
  inherit
    opBinPath
    fromYAML
    readYAML
    toTOML
    globalVariables
    applySubst
    shellIntegrations
    shellIntegrationsNoFish
    shellIntegrationsBashZsh
    theme
    mkEmail
    mkConditionalGithubIncludes
    fishProfilesPath
    kittyProfilesPath
    mkAgenixPathSubst
    ;
}
