{ pkgs, ... }:

{
  programs = {
    bash = {
      enable = true;
    };

    # Enable the fish shell.
    fish = {
      enable = true;
    };
  };

  # Add fish to the list of shells.
  environment.shells = with pkgs; [
    bash
    fish
  ];

  environment.systemPackages = with pkgs; [ sudo ];
}
