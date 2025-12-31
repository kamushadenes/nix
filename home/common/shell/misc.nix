{
  config,
  pkgs,
  lib,
  themes,
  helpers,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      # Disk usage
      dust
      duf

      # Text processing
      gawk
      gnugrep
      unzip
      yq-go

      # System monitoring
      glances
      bandwhich # Network bandwidth by process

      # Modern CLI replacements
      procs # Modern ps
      sd # Modern sed
      doggo # Modern dig/DNS client
      xh # Modern curl/httpie

      # Development utilities
      hyperfine # Command benchmarking
      tokei # Code statistics

      # Quick reference
      tealdeer # tldr - simplified man pages

      # Network utilities
      gping # Ping with graph

      # Field selection
      choose # Modern cut alternative

      # Modern watch
      viddy
    ]
    ++ (with pkgs.unixtools; [ watch ]);

  xdg.configFile."btop/themes/${helpers.theme.variants.underscore}.theme" = {
    source = themes.btopCatppuccin + "/themes/${helpers.theme.variants.underscore}.theme";
  };

  programs = {
    aria2 = {
      enable = true;
    };

    atuin = {
      enable = true;
      flags = [ "--disable-up-arrow" ];
      settings = {
        auto_sync = true;
        sync_frequency = "5m";
        sync_address = "https://atuin.hyades.io";
        search_mode = "prefix";
      };
    } // helpers.shellIntegrationsNoFish;

    bat = {
      enable = true;
      config = lib.mkMerge [
        {
          map-syntax = [ "*.ino:C++" ];
          theme = helpers.theme.variants.titleSpace;
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
        ${helpers.theme.variants.titleSpace} = themes.batCatppuccinMacchiato;
      };
    };

    broot = {
      enable = true;
    } // helpers.shellIntegrations;

    btop = {
      enable = true;
      settings = {
        color_theme = helpers.theme.variants.underscore;
      };
    };

    dircolors = {
      enable = true;
    } // helpers.shellIntegrations;

    direnv = {
      enable = true;

      # Fish integration is always enabled by home-manager
      nix-direnv = {
        enable = true;
      };

      config = {
        load_dotenv = true;
        hide_env_diff = true;
      };
    } // helpers.shellIntegrationsBashZsh;

    eza = {
      enable = true;
      git = true;
      icons = "auto";
    } // helpers.shellIntegrations;

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
      ({
        enable = true;
        # Catppuccin Macchiato
        colors = themes.fzfCatppuccinMacchiato;
        defaultOptions = [
          "--multi"
          "--border"
        ];
      } // helpers.shellIntegrationsNoFish)
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
      # Using evalcache for Fish
    } // helpers.shellIntegrationsNoFish;

    pay-respects = {
      enable = true;
    } // helpers.shellIntegrations;

    ripgrep = {
      enable = true;
    };

    yazi = {
      enable = true;

      theme = lib.mkMerge [
        (builtins.fromTOML (builtins.readFile (themes.yaziCatppuccin + "/themes/${helpers.theme.variants.variantOnly}.toml")))
        {
          manager = {
            syntect_theme = lib.mkForce "${config.xdg.configHome}/bat/themes/${config.programs.bat.config.theme}.tmTheme";
          };
        }
      ];
    } // helpers.shellIntegrations;

    zoxide = {
      enable = true;
    } // helpers.shellIntegrations;
  };
}
