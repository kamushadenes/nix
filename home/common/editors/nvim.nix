{
  inputs,
  pkgs,
  pkgs-unstable,
  lib,
  packages,
  ...
}:
{
  home.packages = with pkgs-unstable; [
    neovide

    # Lua
    pkgs.lua5_1
    pkgs.lua51Packages.luarocks

    # Git
    lazygit

    # tree-sitter
    tree-sitter

    # Python
    python312Packages.pynvim

    # Markdown
    markdownlint-cli2

    # SQL
    sqlfluff

    # Latex
    texliveBasic

    # Misc
    ast-grep
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
      package = pkgs-unstable.neovim-unwrapped;

      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      extraLuaConfig = builtins.readFile ./resources/lazyvim/init.lua;
    };
  };
}
