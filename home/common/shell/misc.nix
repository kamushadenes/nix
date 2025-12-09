{
  config,
  pkgs,
  lib,
  themes,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      dust
      duf
      gawk
      gnugrep
      unzip
      yq-go
      glances
    ]
    ++ (with pkgs.unixtools; [ watch ]);

  xdg.configFile."btop/themes/catppuccin_macchiato.theme" = {
    source = themes.btopCatppuccin + "/themes/catppuccin_macchiato.theme";
  };

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
        auto_sync = true;
        sync_frequency = "5m";
        sync_address = "https://atuin.hyades.io";
        search_mode = "prefix";
      };
    };

    bat = {
      enable = true;
      config = lib.mkMerge [
        {
          map-syntax = [ "*.ino:C++" ];
          theme = "Catppuccin Macchiato";
        }
        (lib.mkIf config.programs.less.enable { pager = lib.getExe pkgs.less; })
      ];
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

    btop = {
      enable = true;
      settings = {
        color_theme = "catppuccin_macchiato";
      };
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
        hide_env_diff = true;
      };
    };

    eza = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;
      git = true;
      icons = "auto";
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

    fzf = lib.mkMerge [
      {
        enable = true;
        enableBashIntegration = config.programs.bash.enable;
        enableZshIntegration = config.programs.zsh.enable;
        # Using evalcache
        enableFishIntegration = false;
        # Catppuccin Macchiato
        colors = themes.fzfCatppuccinMacchiato;
        defaultOptions = [
          "--multi"
          "--border"
        ];
      }
      (lib.mkIf config.programs.fd.enable {
        changeDirWidgetCommand = "${lib.getExe config.programs.fd.package} --type d";
        defaultCommand = "${lib.getExe config.programs.fd.package} --type f";
        fileWidgetCommand = "${lib.getExe config.programs.fd.package} --type f";
      })
    ];

    htop = {
      enable = true;
    };

    jq = {
      enable = true;
    };

    less = {
      enable = true;
    };

    navi = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      # Using evalcache
      enableFishIntegration = false;
    };

    pay-respects = {
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
