{
  config,
  lib,
  themes,
  ...
}:
{
  programs = {
    starship = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;

      # Using evalcache
      enableFishIntegration = false;

      settings = {
        add_newline = true;
        command_timeout = 2000;

        palette = "catppuccin_macchiato";

        palettes =
          (builtins.fromTOML (builtins.readFile (themes.starshipCatppuccin + "/themes/macchiato.toml")))
          .palettes;

        format = lib.concatStringsSep "" [
          "$username"
          "$hostname"
          "$directory"
          "$character"
        ];

        right_format = lib.concatStringsSep "" [
          "$cmd_duration"
          "$all"
        ];

        azure = {
          disabled = true;
        };

        battery = {
          disabled = true;
        };

        character = {
          success_symbol = "[❯](peach)";
          error_symbol = "[[✗](red) ❯](peach)";
          vimcmd_symbol = "[❮](subtext1)";
        };

        cobol = {
          disabled = true;
        };

        conda = {
          disabled = true;
        };

        container = {
          disabled = true;
        };

        crystal = {
          disabled = true;
        };

        daml = {
          disabled = true;
        };

        dart = {
          disabled = true;
        };

        deno = {
          disabled = true;
        };

        directory = {
          truncation_length = 4;
          style = "bold lavender";
        };

        direnv = {
          disabled = true;
        };

        docker_context = {
          disabled = true;
        };

        dotnet = {
          disabled = true;
        };

        elixir = {
          disabled = true;
        };

        elm = {
          disabled = true;
        };

        erlang = {
          disabled = true;
        };

        fennel = {
          disabled = true;
        };

        gcloud = {
          detect_env_vars = [ "GOOGLE_CLOUD_PROJECT" ];
        };

        git_branch = {
          style = "bold mauve";
        };

        git_commit = {
          disabled = false;
        };

        git_state = {
          disabled = false;
        };

        git_metrics = {
          disabled = true;
        };

        git_status = {
          disabled = false;
        };

        gleam = {
          disabled = true;
        };

        golang = {
          symbol = " ";
        };

        guix_shell = {
          disabled = true;
        };

        gradle = {
          disabled = true;
        };

        haskell = {
          disabled = true;
        };

        haxe = {
          disabled = true;
        };

        helm = {
          disabled = true;
        };

        hostname = {
          ssh_only = true;
          disabled = false;
        };

        java = {
          disabled = true;
        };

        jobs = {
          disabled = false;
        };

        julia = {
          disabled = true;
        };

        kotlin = {
          disabled = true;
        };

        kubernetes = {
          disabled = true;
        };

        localip = {
          disabled = true;
        };

        lua = {
          disabled = true;
        };

        memory_usage = {
          disabled = true;
        };

        meson = {
          disabled = true;
        };

        nats = {
          disabled = true;
        };

        nim = {
          disabled = true;
        };

        nix_shell = {
          disabled = true;
        };

        nodejs = {
          disabled = false;
        };

        ocaml = {
          disabled = true;
        };

        odin = {
          disabled = true;
        };

        opa = {
          disabled = true;
        };

        openstack = {
          disabled = true;
        };

        os = {
          disabled = true;
          symbols = {
            Windows = " ";
            Macos = " ";
            Linux = " ";
          };
        };

        package = {
          disabled = false;
        };

        perl = {
          disabled = true;
        };

        php = {
          disabled = true;
        };

        pijul_channel = {
          disabled = true;
        };

        pulumi = {
          disabled = true;
        };

        purescript = {
          disabled = true;
        };

        python = {
          disabled = false;
        };

        quarto = {
          disabled = true;
        };

        rlang = {
          disabled = true;
        };

        raku = {
          disabled = true;
        };

        red = {
          disabled = true;
        };

        ruby = {
          disabled = true;
        };

        rust = {
          disabled = false;
        };

        scala = {
          disabled = true;
        };

        shell = {
          disabled = true;
        };

        shlvl = {
          disabled = true;
        };

        singularity = {
          disabled = true;
        };

        solidity = {
          disabled = true;
        };

        spack = {
          disabled = true;
        };

        status = {
          disabled = true;
        };

        sudo = {
          disabled = true;
        };

        swift = {
          disabled = true;
        };

        terraform = {
          disabled = false;
        };

        time = {
          disabled = true;
        };

        typst = {
          disabled = true;
        };

        username = {
          show_always = false;
          disabled = false;
        };

        vagrant = {
          disabled = true;
        };

        vlang = {
          disabled = true;
        };

        vcsh = {
          disabled = true;
        };

        zig = {
          disabled = true;
        };
      };
      enableTransience = true;
    };
  };
}
