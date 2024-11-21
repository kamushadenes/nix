{
  config,
  pkgs,
  pkgs-unstable,
  lib,
  ...
}:
{
  programs = {
    emacs = {
      enable = false; # Temporarily disable
      package = pkgs-unstable.emacs30-pgtk;
    };
  };

  home.packages =
    with pkgs-unstable;
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
    rev = "7bc39f2c1402794e76ea10b781dfe586fed7253b";
  };

  xdg.configFile."doom".source = ./resources/doom;
}
