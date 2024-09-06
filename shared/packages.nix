{ pkgs, ... }:
{
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

  monaspice = pkgs.stdenv.mkDerivation rec {
    pname = "monaspice";
    version = "3.2.1";
    src = pkgs.fetchzip {
      url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Monaspace.zip";
      stripRoot = false;
      hash = "sha256-sB7XpZvkVK5zIhhgPn2180UZwyOWNNNTzM7Sh08lXkY=";
    };

    outputs = [ "out" ];

    installPhase = ''
      runHook preInstall

      install -Dm644 *.otf -t $out/share/fonts/opentype

      runHook postInstall
    '';

    meta = with pkgs; {
      description = "An innovative superfamily of fonts for code - NerdFonts patched";
      homepage = "https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/Monaspace";
      license = lib.licenses.ofl;
      platforms = lib.platforms.all;
    };
  };

  sbarlua = pkgs.stdenv.mkDerivation rec {
    pname = "sbarlua";
    version = "1.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "FelixKratz";
      repo = "SbarLua";
      rev = "437bd2031da38ccda75827cb7548e7baa4aa9978";
      hash = "sha256-F0UfNxHM389GhiPQ6/GFbeKQq5EvpiqQdvyf7ygzkPg=";
    };

    nativeBuildInputs = with pkgs; [
      clang
      gcc
    ];
    buildInputs = with pkgs; [ readline ];
    outputs = [ "out" ];

    installPhase = ''
      mv bin "$out"
    '';

    meta = with pkgs; {
      description = "A Lua API for SketchyBar";
      homepage = "https://github.com/FelixKratz/SbarLua";
      license = lib.licenses.gpl3;
      platforms = lib.platforms.darwin;
    };
  };
}
