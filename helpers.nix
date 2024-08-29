{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  # 1Password Binary Path
  opBinPath = "${pkgs._1password}/bin/op";

  # YAML reading functions
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
            ${pkgs.remarshal}/bin/remarshal  \
              -if yaml \
              -i <(echo "$yaml") \
              -of json \
              -o $out
          ''
      )
    );

  # Global Variables
  globalVariables = {
    base = {
      DOOMDIR = "${config.xdg.configHome}/doom";
      EMACSDIR = "${config.xdg.configHome}/emacs";
      DOOMLOCALDIR = "${config.xdg.dataHome}/doom";
      DOOMPROFILELOADFILE = "${config.xdg.stateHome}/doom-profiles-load.el";

      NIX_HM_PROFILE = config.home.profileDirectory;

      OP_BIN_PATH = opBinPath;

      FLAKE = "${config.home.homeDirectory}/.config/nix/config/?submodules=1";
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
in
{
  # YAML reading functions
  fromYAML = fromYAML;
  readYAML = path: fromYAML (builtins.readFile path);

  # Helper function to prevent email scraping
  mkEmail = user: domain: "${user}@${domain}";

  # Helper function to generate conditional includes for GitHub
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

  # Helper functions to generate profile paths for fish and kitty
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

  # Global Variables
  globalVariables = globalVariables;

  # 1Password Binary Path
  opBinPath = opBinPath;
}