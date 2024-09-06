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
  opBinPath = lib.getExe pkgs._1password;

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
            ${lib.getExe pkgs.remarshal} -if yaml -i <(echo "$yaml") -of json -o $out
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
          ${lib.getExe pkgs.remarshal} -if json -i <(echo "$json") -of toml -o $out
        ''
    );

  ########################################
  #                                      #
  # Global Variables                     #
  #                                      #
  ########################################

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

      FLAKE = "${config.home.homeDirectory}/.config/nix/config/?submodules=1";
      DARWIN_USER_TEMP_DIR = lib.optionals pkgs.stdenv.isDarwin ''$(${lib.getExe' pkgs.coreutils "printf"} '%s' "$(${lib.getExe pkgs.getconf} DARWIN_USER_TEMP_DIR)" | ${lib.getExe' pkgs.coreutils "tr"} -d "\n")'';

      # Work around https://github.com/Homebrew/brew/issues/13219
      HOMEBREW_SSH_CONFIG_PATH = "${config.xdg.configHome}/ssh/brew_config";

      LUA_PATH = "${config.xdg.configHome}/sketchybar/?.lua;${config.xdg.configHome}/sketchybar_helpers/?/init.lua;./?.lua";
    };

    launchctl = lib.concatMapStringsSep "\n" (var: ''
      run /bin/launchctl setenv ${var} "${globalVariables.base.${var}}"
    '') (lib.attrNames globalVariables.base);

    shell = lib.concatMapStringsSep "\n" (var: ''
      export ${var}="${globalVariables.base.${var}}"
    '') (lib.attrNames globalVariables.base);

    fishShell = lib.concatMapStringsSep "\n" (var: ''
      set -x ${var} "${globalVariables.base.${var}}"
    '') (lib.attrNames globalVariables.base);
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

  ########################################
  #                                      #
  # Backrest Configuration Functions     #
  #                                      #
  ########################################

  mkBackrestConfig = machine: repos: plans: auth: {
    modno = 1;
    instance = machine;
    repos = repos;
    plans = plans;
    auth = auth;
  };

  mkBackrestRepo = name: uri: passwordFile: prunePolicy: checkPolicy: {
    id = name;
    uri = uri;
    env = [ "RESTIC_PASSWORD_FILE=${passwordFile}" ];
    prunePolicy = lib.mkMerge [
      {
        schedule = {
          maxFrequencyDays = 7;
          onError = "ON_ERROR_IGNORE";
        };
      }
      (lib.mkForce prunePolicy)
    ];

    checkPolicy = lib.mkMerge [
      { readDataSubsetPercent = 0; }
      (lib.mkForce checkPolicy)
    ];
  };

  mkBackrestPlan = name: repo: paths: excludes: schedule: retention: flags: healthCheckId: {
    id = name;
    repo = repo;
    paths = paths;
    excludes = excludes;
    schedule = schedule;
    retention = lib.mkMerge [
      {
        policyTimeBucketed = {
          hourly = 24;
          daily = 7;
          weekly = 4;
          monthly = 3;
        };
      }
      (lib.mkForce retention)
    ];
    backup_flags = [
      "--exclude-if-present .nobackup"
      "--exclude-caches"
    ] ++ flags;
    hooks = [
      {
        conditions = [ "CONDITION_SNAPSHOT_START" ];
        actionCommand = {
          command = "${lib.getExe pkgs.curl} -fsS --retry 3 https://hc-ping.com/${healthCheckId}/start";
        };
        onError = "ON_ERROR_IGNORE";
      }
      {
        conditions = [ "CONDITION_SNAPSHOT_SUCCESS" ];
        actionCommand = {
          command = "${lib.getExe pkgs.curl} -fsS --retry 3 https://hc-ping.com/${healthCheckId}";
        };
        onError = "ON_ERROR_IGNORE";
      }
      {
        conditions = [ "CONDITION_SNAPSHOT_ERROR" ];
        actionCommand = {
          command = "${lib.getExe pkgs.curl} -fsS --retry 3 https://hc-ping.com/${healthCheckId}/fail";
        };
        onError = "ON_ERROR_IGNORE";
      }
      (lib.mkIf pkgs.stdenv.isDarwin {
        conditions = [ "CONDITION_SNAPSHOT_ERROR" ];
        actionCommand = {
          command = ''
            /usr/bin/osascript -e 'display notification "{{ .ShellEscape .Task }} failed" with title "Backrest"'
          '';
        };
        onError = "ON_ERROR_IGNORE";
      })
    ];
  };
in
{
  # 1Password Binary Path
  opBinPath = opBinPath;

  # YAML reading functions
  fromYAML = fromYAML;
  readYAML = readYAML;

  # TOML rendering functions
  toTOML = toTOML;

  # Global Variables
  globalVariables = globalVariables;

  # Email Helper Functions
  mkEmail = mkEmail;

  # Git Helper Functions
  mkConditionalGithubIncludes = mkConditionalGithubIncludes;

  # Fish Configuration Functions
  fishProfilesPath = fishProfilesPath;

  # Kitty Configuration Functions
  kittyProfilesPath = kittyProfilesPath;

  # Agenix Helper Functions
  mkAgenixPathSubst = mkAgenixPathSubst;

  # Backrest Configuration Functions
  mkBackrestConfig = mkBackrestConfig;
  mkBackrestRepo = mkBackrestRepo;
  mkBackrestPlan = mkBackrestPlan;
}
