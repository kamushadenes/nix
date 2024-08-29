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

      coc = {
        enable = true;
      };

      plugins = with pkgs.vimPlugins; [
        catppuccin-nvim
        firenvim
        nvim-autopairs
        nerdtree
        neogit
        plenary-nvim
        go-nvim
      ];
    };
  };
}
