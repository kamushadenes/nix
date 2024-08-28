{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  programs = {
    neovim = {
      enable = true;

      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      extraLuaConfig = builtins.readFile ./resources/nvim/init.lua;

      plugins = with pkgs.vimPlugins; [
        catppuccin-nvim
        firenvim
      ];
    };
  };
}
