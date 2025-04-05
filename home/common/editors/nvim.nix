{
  config,
  inputs,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  home.packages = with pkgs-unstable; [
    neovide

    # Lua
    pkgs.lua5_1
    pkgs.lua51Packages.luarocks

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

    # nvim-staging
    (writeScriptBin "nvim-staging" ''
      #!/bin/bash
      export NVIM_APPNAME=nvim-staging
      exec nvim $@
    '')

    # AI
    inputs.mcp-hub.packages."${system}".default
  ];

  # Use NVIM_APPNAME=nvim-staging to be able to update packages, then rebuild
  home.file."${config.xdg.configHome}/nvim-staging".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/config/home/common/editors/resources/lazyvim";

  xdg.configFile."nvim/lua" = {
    source = ./resources/lazyvim/lua;
    recursive = true;
  };

  xdg.configFile."nvim/.neoconf.json".source = ./resources/lazyvim/.neoconf.json;
  xdg.configFile."nvim/stylua.toml".source = ./resources/lazyvim/stylua.toml;
  xdg.configFile."nvim/lazyvim.json".source = ./resources/lazyvim/lazyvim.json;
  xdg.configFile."nvim/lazy-lock.json".source = ./resources/lazyvim/lazy-lock.json;

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
