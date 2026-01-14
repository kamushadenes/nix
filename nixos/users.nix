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
      linger = true; # Enable persistent user session for systemd user services
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
