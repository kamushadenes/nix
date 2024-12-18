{ ... }:

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
    "obsidian"
  ];

  homebrew.brews = [
    "cava"
    "dockutil"
    "ical-buddy"
    "ifstat"
    {
      name = "sketchybar"; # It's easier to grant permissions through brew than home-manager
      restart_service = false;
      start_service = true;
    }
    "switchaudio-osx"
  ];
}
