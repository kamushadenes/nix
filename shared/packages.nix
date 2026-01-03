{ pkgs, lib, ... }:
let
  gitSquash = pkgs.fetchFromGitHub {
    owner = "sheerun";
    repo = "git-squash";
    rev = "e87fb1d410edceec3670101e2cf89297ecab5813";
    hash = "sha256-yvufKIwjP7VcIzLi8mE228hN4jmaqk90c8oxJtkXEP8=";
  };

  colorScript = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/nix-community/home-manager/b3a9fb9d05e5117413eb87867cebd0ecc2f59b7e/lib/bash/home-manager.sh";
    sha256 = "90ea66d50804f355801cd8786642b46991fc4f4b76180f7a72aed02439b67d08";
  };

  lazyworktree = pkgs.buildGoModule rec {
    pname = "lazyworktree";
    version = "1.14.0";

    src = pkgs.fetchFromGitHub {
      owner = "chmouel";
      repo = "lazyworktree";
      rev = "v${version}";
      hash = "sha256-lwz8tU1/PhDbLpyI1ZvCf3d5IqfGW+0pqI+q8TVQLSg=";
    };

    vendorHash = "sha256-qqbNqQ2dYNtot2yt5bOZDTbgze8ZrNZC5w22oRiiD3o=";

    # Tests require git which isn't available in sandbox
    doCheck = false;

    ldflags = [
      "-s"
      "-w"
      "-X main.version=${version}"
    ];

    meta = {
      description = "A simple Terminal UI to manage git worktrees";
      homepage = "https://github.com/chmouel/lazyworktree";
      license = lib.licenses.asl20;
      mainProgram = "lazyworktree";
    };
  };
in
{
  inherit gitSquash colorScript lazyworktree;
}
