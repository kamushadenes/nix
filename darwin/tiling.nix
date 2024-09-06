{ pkgs, ... }:

{
  homebrew.taps = [
    "nikitabobko/tap"
    "FelixKratz/formulae"
  ];

  homebrew.casks = [ "aerospace" ];

  homebrew.brews = [ "borders" ];
}
