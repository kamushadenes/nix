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
    users = lib.mkMerge [
      {
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
        name = "brewers";
        description = "Homebrew users";
        members =
          with config.users.users;
          [ kamushadenes.name ] ++ (lib.optionals shared [ yjrodrigues.name ]);
      };
    };
  };
}
