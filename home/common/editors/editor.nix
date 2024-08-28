{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [ nano ];

  home.sessionVariables = {
    # Vim is better for quick edits
    EDITOR = "nvim";
  };
}
