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
          uid = 555;
          gid = 555;
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
        gid = 555;
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
