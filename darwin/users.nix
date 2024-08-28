{ pkgs, ... }:

{
  # Manage user accounts.
  users.users = {
    kamushadenes = {
      name = "kamushadenes";
      home = "/Users/kamushadenes";
      shell = pkgs.fish;
    };
  };
}
