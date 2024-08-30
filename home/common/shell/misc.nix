{
  inputs,
  config,
  pkgs,
  lib,
  osConfig,
  themes,
  ...
}:
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
      # Using evalcache
      enableFishIntegration = false;

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
        "Catppuccin Macchiato" = themes.batCatppuccinMacchiato;
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
      # Using evalcache
      enableFishIntegration = false;
      changeDirWidgetCommand = "fd --type d";
      defaultCommand = "fd --type f";
      fileWidgetCommand = "fd --type f";

      # Catppuccin Macchiato
      colors = themes.fzfCatppuccinMacchiato;
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
      # Using evalcache
      enableFishIntegration = false;
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
        (builtins.fromTOML (builtins.readFile (themes.yaziCatppuccin + "/themes/macchiato.toml")))
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
