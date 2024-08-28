{ pkgs, ... }:
let
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
in
{
  # Fonts
  fonts = {
    packages = with pkgs; [
      monaspace
      nerdfonts
      monaspice
    ];
  };
}
