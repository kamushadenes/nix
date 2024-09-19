{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs = {
    emacs = {
      enable = true;
      package = pkgs.emacs29-pgtk;
    };
  };

  home.packages =
    with pkgs;
    [
      # GNU Tools
      coreutils-prefixed

      # Spell checking
      aspell

      # Ansible
      ansible

      # Docker
      dockfmt

      # Editorconfig
      editorconfig-core-c

      # CC
      clang-tools

      # Go
      gore
      gomodifytags
      gotools
      gotests

      # Markdown
      markdownlint-cli
      pandoc

      # Nix
      nixfmt-rfc-style

      # PHP
      php83
      php83Packages.composer

      # Python
      python312Packages.pyflakes
      python312Packages.isort
      pipenv
      python312Packages.pynose
      python312Packages.pytest
      python312Packages.cython
      python312Packages.grip
      pyright

      # RST
      rstfmt

      # Rust
      rustup

      # SH
      shfmt
      shellcheck

      # Web
      stylelint
      jsbeautifier
      nodePackages.prettier
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      # Org
      pngpaste
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # Org
      libxml2
      scrot
      xclip

      # Web
      html-tidy
    ];

  home.sessionPath = [ "${config.xdg.configHome}/emacs/bin" ];

  xdg.configFile."emacs".source = builtins.fetchGit {
    url = "https://github.com/doomemacs/doomemacs.git";
    rev = "e21e01d4c27e357ce3588d46c5bb681277b320c1";
  };

  xdg.configFile."doom".source = ./resources/doom;
}
