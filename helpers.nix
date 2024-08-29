{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
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
in
{
  fromYAML = fromYAML;
  readYAML = path: fromYAML (builtins.readFile path);
  #
  # Helper function to prevent email scraping
  mkEmail = user: domain: "${user}@${domain}";

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

  setProfilesPath =
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
}
