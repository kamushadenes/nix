{
  config,
  lib,
  pkgs,
  ...
}:
let
  starshipCatppuccin = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "starship";
    rev = "0cf91419f9649e9a47bb5c85797e4b83ecefe45c";
    hash = "sha256-2JLybPsgFZ/Fzz4e0dd4Vo0lfi4tZVnRbw/jUCmN6Rw=";
  };
in
{
  programs = {
    starship = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;

      settings = {
        add_newline = true;
        command_timeout = 2000;

        palette = "catppuccin_macchiato";

        palettes =
          (builtins.fromTOML (builtins.readFile (starshipCatppuccin + "/themes/macchiato.toml"))).palettes;

        format = lib.concatStringsSep "" [
          "$os"
          "$directory"
          "$character"
        ];

        right_format = lib.concatStringsSep "" [
          "$cmd_duration"
          "$nodejs"
          "$all"
        ];

        git_branch = {
          style = "bold mauve";
        };

        nix_shell = {
          disabled = true;
        };

        docker_context = {
          disabled = true;
        };

        golang = {
          symbol = " ";
        };

        directory = {
          truncation_length = 4;
          style = "bold lavender";
        };

        gcloud = {
          detect_env_vars = [ "GOOGLE_CLOUD_PROJECT" ];
        };

        character = {
          success_symbol = "[❯](peach)";
          error_symbol = "[[✗](red) ❯](peach)";
          vimcmd_symbol = "[❮](subtext1)";
        };
      };
      enableTransience = true;
    };
  };
}
