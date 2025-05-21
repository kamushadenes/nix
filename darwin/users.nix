{
  config,
  lib,
  pkgs,
  shared,
  ...
}:

{
  # Manage user accounts.
  users = {
    knownUsers = [ "homebrew" ];
    knownGroups = [ "brewers" ];
    users = lib.mkMerge [
      {
        homebrew = {
          uid = 505;
          gid = 505;
          name = "homebrew";
          home = "/opt/homebrew";
          shell = pkgs.zsh;
          createHome = false;
          isHidden = true;
        };
        kamushadenes = {
          name = "kamushadenes";
          home = "/Users/kamushadenes";
          shell = pkgs.fish;
        };
      }
      (lib.mkIf shared {
        yjrodrigues = {
          name = "yjrodrigues";
          home = "/Users/yjrodrigues";
          shell = pkgs.zsh;
          createHome = true;
        };
      })
    ];
    groups = {
      brewers = {
        gid = 505;
        name = "brewers";
        description = "homebrew users";
        members =
          with config.users.users;
          [
            kamushadenes.name
            homebrew.name
          ]
          ++ (lib.optionals shared [ yjrodrigues.name ]);
      };
    };
  };
}
