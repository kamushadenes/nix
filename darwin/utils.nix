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
    "background-music"
  ];

  homebrew.brews = [
    {
      name = "sketchybar"; # Easier to grant permissions through brew
      restart_service = false;
      start_service = true;
    }
    "ical-buddy"
    "ifstat"
    "cava"
  ];
}
