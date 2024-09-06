{ pkgs, ... }:

{
  homebrew.taps = [
    "nikitabobko/tap"
    "FelixKratz/formulae"
  ];

  # Casks
  homebrew.casks = [
    "hazel"
    "pdf-expert"
    "qbittorrent"
    "raycast"
    "uhk-agent"
    "launchcontrol"
    "clickup"

    "aerospace"
    "borders"
  ];
}
