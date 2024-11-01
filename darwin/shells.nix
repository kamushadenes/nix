{ pkgs, ... }:

{
  # Casks
  #homebrew.casks = [ "git-credential-manager" ];

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
}
