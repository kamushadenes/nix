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

  # Happy Coder CLI - Mobile and Web client wrapper for Claude Code and Codex
  # Built from the happy-cli repository (not the main happy repo)
  happy-coder = pkgs.mkYarnPackage rec {
    pname = "happy-coder";
    version = "0.13.0";

    src = pkgs.fetchFromGitHub {
      owner = "slopus";
      repo = "happy-cli";
      rev = "f9cb1216bdaacd885cd55d7eae676ad6c675a48a"; # v0.13.0 commit
      hash = "sha256-q4o8FHBhZsNL+D8rREjPzI1ky5+p3YNSxKc1OlA2pcs=";
    };

    offlineCache = pkgs.fetchYarnDeps {
      yarnLock = "${src}/yarn.lock";
      hash = "sha256-DlUUAj5b47KFhUBsftLjxYJJxyCxW9/xfp3WUCCClDY=";
    };

    buildPhase = ''
      export HOME=$PWD
      yarn --offline run build
    '';

    distPhase = "true"; # Skip the default dist phase

    meta = {
      description = "Mobile and Web client for Claude Code and Codex";
      homepage = "https://github.com/slopus/happy-cli";
      license = lib.licenses.mit;
      mainProgram = "happy";
    };
  };
in
{
  inherit gitSquash colorScript lazyworktree happy-coder;
}
