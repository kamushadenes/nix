{
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; lib.optionals pkgs.stdenv.isLinux [ aircrack-ng ];

  # Enable ssh-agent systemd service on Linux
  services.ssh-agent.enable = true;
}
