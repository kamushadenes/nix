{
  inputs,
  config,
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  batCatppuccinMacchiato = {
    src = pkgs.fetchFromGitHub {
      owner = "catppuccin";
      repo = "bat";
      rev = "d3feec47b16a8e99eabb34cdfbaa115541d374fc";
      hash = "sha256-s0CHTihXlBMCKmbBBb8dUhfgOOQu9PBCQ+uviy7o47w=";
    };
    file = "themes/Catppuccin Macchiato.tmTheme";
  };

  yaziCatppuccin = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "yazi";
    rev = "37dec9bf1f7e52e0d593c225827b9dbc71ce504c";
    hash = "sha256-oJo52hMSK7mr5f0DtnyaN1FVOSKKUOHWCT80V1qfyrU=";
  };

  fzfCatppuccinMacchiato = {
    "bg+" = "#363a4f";
    "bg" = "#24273a";
    "spinner" = "#f4dbd6";
    "hl" = "#ed8796";
    "fg" = "#cad3f5";
    "header" = "#ed8796";
    "info" = "#c6a0f6";
    "pointer" = "#f4dbd6";
    "marker" = "#b7bdf8";
    "fg+" = "#cad3f5";
    "prompt" = "#c6a0f6";
    "hl+" = "#ed8796";
    "selected-bg" = "#494d64";
  };
in
{
  home.packages =
    with pkgs;
    [
      du-dust
      duf
      gawk
      gnugrep
      unzip
      yq-go
    ]
    ++ (with pkgs.unixtools; [ watch ]);

  programs = {
    aria2 = {
      enable = true;
    };

    atuin = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;

      flags = [ "--disable-up-arrow" ];

      settings = {
        #auto_sync = true;
        #sync_frequency = "5m";
        #sync_address = "https://api.atuin.sh";
        #search_mode = "prefix";
      };
    };

    bat = {
      enable = true;
      config = {
        map-syntax = [ "*.ino:C++" ];
        theme = "Catppuccin Macchiato";
      };
      extraPackages = with pkgs.bat-extras; [
        batdiff
        batman
        batgrep
        batpipe
        batwatch
        prettybat
      ];
      themes = {
        "Catppuccin Macchiato" = batCatppuccinMacchiato;
      };
    };

    broot = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;
    };

    dircolors = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;
    };

    direnv = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;

      # Always enabled for fish
      #enableFishIntegration = config.programs.fish.enable;

      nix-direnv = {
        enable = true;
      };

      config = {
        load_dotenv = true;
      };
    };

    eza = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;
      git = true;
      icons = true;
    };

    fastfetch = {
      enable = true;
    };

    fd = {
      enable = true;
      ignores = [
        ".git/"
        "*.bak"
      ];
    };

    fzf = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;
      changeDirWidgetCommand = "fd --type d";
      defaultCommand = "fd --type f";
      fileWidgetCommand = "fd --type f";

      # Catppuccin Macchiato
      colors = fzfCatppuccinMacchiato;
      defaultOptions = [
        "--multi"
        "--border"
      ];
    };

    htop = {
      enable = true;
    };

    jq = {
      enable = true;
    };

    navi = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;
    };

    thefuck = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;
    };

    ripgrep = {
      enable = true;
    };

    yazi = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;

      theme = lib.mkMerge [
        (builtins.fromTOML (builtins.readFile (yaziCatppuccin + "/themes/macchiato.toml")))
        {
          manager = {
            syntect_theme = lib.mkForce "${config.xdg.configHome}/bat/themes/${config.programs.bat.config.theme}.tmTheme";
          };
        }
      ];
    };

    zoxide = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;
    };
  };
}
