{ pkgs, ... }:

{
  # Manage user accounts.
  users.users = {
    kamushadenes = {
      name = "kamushadenes";
      home = "/home/kamushadenes";
      isNormalUser = true;
      group = "kamushadenes";
      shell = pkgs.fish;
      extraGroups = [
        "audio"
        "networkmanager"
        "video"
        "wheel"
      ];
    };
  };

  users.groups.kamushadenes = { };
}
