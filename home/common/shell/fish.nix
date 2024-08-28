{
  inputs,
  config,
  pkgs,
  lib,
  osConfig,
  globalVariables,
  ...
}:
let
  setProfilesPath =
    let
      dquote = str: "\"" + str + "\"";

      makeBinPathList = map (path: path + "/bin");
    in
    ''
      fish_add_path --move --prepend --path ${
        lib.concatMapStringsSep " " dquote (makeBinPathList osConfig.environment.profiles)
      }
      set fish_user_paths $fish_user_paths
    '';
in
{
  home.sessionVariables = globalVariables.base;

  programs = {
    fish = {
      enable = true;
      functions = lib.mkMerge [
        {
          mkcd = {
            body = "mkdir -p $argv and cd $argv";
          };

          fish_greeting = {
            body = "";
          };
        }

        (lib.mkIf config.programs.starship.enable {
          starship_transient_prompt_func = {
            body = "starship module character";
          };

          starship_transient_rprompt_func = {
            body = "";
          };
        })
      ];

      shellInit = lib.mkMerge [
        # Darwin
        (lib.mkIf (pkgs.stdenv.isDarwin) ''
          # Setup homebrew
          /opt/homebrew/bin/brew shellenv | source
        '')

        (lib.mkIf config.programs.yazi.enable ''
          if test $fish_key_bindings = fish_default_key_bindings
              bind \cf ya
          else
              bind -M insert \cf ya
          end
        '')

        # Common
        ''
          fish_add_path -a '${config.home.homeDirectory}/.cargo/bin'
          fish_add_path -a '${config.home.homeDirectory}/.config/emacs/bin'
          fish_add_path -a '${config.home.homeDirectory}/.krew/bin'

          ${globalVariables.fishShell}

          # Docker host running on a remote machine
          set -x DOCKER_HOST "tcp://10.23.23.204:2375"

          # SSH Keys
          ssh-add -q /Users/kamushadenes/.ssh/keys/id_ed25519

          # Move Nix paths back to the front
          ${setProfilesPath};
        ''
      ];

      loginShellInit = setProfilesPath;

      shellAliases = lib.mkMerge [
        {
          rebuild =
            if osConfig.programs.nh.enable then
              ''nh os switch -H (hostname -s | sed s"/.local//g")''
            else if pkgs.stdenv.isDarwin then
              ''darwin-rebuild switch --flake "${globalVariables.base.FLAKE}"''
            else
              ''sudo nixos-rebuild switch --flake "${globalVariables.base.FLAKE}"'';
        }

        (lib.mkIf pkgs.stdenv.isDarwin { nh = "nh_darwin"; })

        (lib.mkIf config.programs.bat.enable { cat = "bat -p"; })
        (lib.mkIf config.programs.broot.enable { tree = "broot"; })
        (lib.mkIf config.programs.eza.enable { ls = "eza --icons -F -H --group-directories-first --git"; })
        (lib.mkIf config.programs.kitty.enable {
          ssh = "kitten ssh";
          sudo = ''sudo TERMINFO="$TERMINFO"'';
        })
      ];
    };
  };
}
