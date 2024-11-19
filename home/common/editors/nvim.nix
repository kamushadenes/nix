{
  inputs,
  pkgs,
  lib,
  packages,
  ...
}:
{
  home.packages = with pkgs; [
    neovide
  ];

  xdg.configFile."nvim/lua" = {
    source = ./resources/lazyvim/lua;
    recursive = true;
  };

  xdg.configFile."nvim/.neoconf.json".source = ./resources/lazyvim/.neoconf.json;
  xdg.configFile."nvim/stylua.toml".source = ./resources/lazyvim/stylua.toml;
  xdg.configFile."nvim/lazyvim.json".source = ./resources/lazyvim/lazyvim.json;

  programs = {
    neovim = {
      enable = true;
      package = pkgs.neovim-unwrapped;

      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      extraLuaConfig = builtins.readFile ./resources/lazyvim/init.lua;
    };
  };
}
