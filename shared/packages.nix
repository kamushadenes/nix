{ lib, pkgs, ... }:
let
  gitSquash = pkgs.fetchFromGitHub {
    owner = "sheerun";
    repo = "git-squash";
    rev = "e87fb1d410edceec3670101e2cf89297ecab5813";
    hash = "sha256-yvufKIwjP7VcIzLi8mE228hN4jmaqk90c8oxJtkXEP8=";
  };

  kitty-scrollback = pkgs.vimUtils.buildVimPlugin {
    name = "kitty-scrollback.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "mikesmithgh";
      repo = "kitty-scrollback.nvim";
      rev = "3f430ff8829dc2b0f5291d87789320231fdb65a1";
      hash = "sha256-6aU9lXfRtxJA/MYkaJ4iRQYAnpBBSGI1R6Ny048aJx8=";
    };
  };

  colorScript = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/nix-community/home-manager/b3a9fb9d05e5117413eb87867cebd0ecc2f59b7e/lib/bash/home-manager.sh";
    sha256 = "90ea66d50804f355801cd8786642b46991fc4f4b76180f7a72aed02439b67d08";
  };
in
{
  gitSquash = gitSquash;
  kitty-scrollback = kitty-scrollback;
  colorScript = colorScript;
}
