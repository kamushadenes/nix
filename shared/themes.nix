{ pkgs, ... }:
{
  batCatppuccinMacchiato = {
    src = pkgs.fetchFromGitHub {
      owner = "catppuccin";
      repo = "bat";
      rev = "699f60fc8ec434574ca7451b444b880430319941";
      hash = "sha256-6fWoCH90IGumAMc4buLRWL0N61op+AuMNN9CAR9/OdI=";
    };
    file = "themes/Catppuccin Macchiato.tmTheme";
  };

  btopCatppuccin = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "btop";
    rev = "f437574b600f1c6d932627050b15ff5153b58fa3";
    hash = "sha256-mEGZwScVPWGu+Vbtddc/sJ+mNdD2kKienGZVUcTSl+c=";
  };

  deltaCatppuccin = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "delta";
    rev = "b88f87aedbeb7dc74c38831cf385819b69b78cbe";
    hash = "sha256-/zLkxfpTkZ744hUNANFmm96q81ydFM7EcxOj+0GoaGU=";
  };

  fzfCatppuccinMacchiato = {
    "bg+" = "#363a4f";
    "bg" = "#24273a";
    "spinner" = "#f4dbd6";
    "hl" = "#ed8796";
    "fg" = "#cad3f5";
    "header" = "#ed8796";
    "info" = "#c6a0f6";
    "pointer" = "#f4dbd6";
    "marker" = "#b7bdf8";
    "fg+" = "#cad3f5";
    "prompt" = "#c6a0f6";
    "hl+" = "#ed8796";
    "selected-bg" = "#494d64";
  };

  k9sCatppuccin = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "k9s";
    rev = "4432383da214face855a873d61d2aa914084ffa2";
    hash = "sha256-GFWOldDhpn98X9eEaMVjhZtGDKxNukmSR2EZqAAOH6o=";
  };

  starshipCatppuccin = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "starship";
    rev = "0cf91419f9649e9a47bb5c85797e4b83ecefe45c";
    hash = "sha256-2JLybPsgFZ/Fzz4e0dd4Vo0lfi4tZVnRbw/jUCmN6Rw=";
  };

  yaziCatppuccin = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "yazi";
    rev = "37dec9bf1f7e52e0d593c225827b9dbc71ce504c";
    hash = "sha256-oJo52hMSK7mr5f0DtnyaN1FVOSKKUOHWCT80V1qfyrU=";
  };
}
