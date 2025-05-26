{ pkgs, ... }:

{
  homebrew.taps = [
    "nikitabobko/tap"
    "FelixKratz/formulae"
    "xpipe-io/tap"
  ];

  # Casks
  homebrew.casks = [
    "dockside"
    "hazel"
    "pdf-expert"
    "qbittorrent"
    "raycast"
    "uhk-agent"
    "launchcontrol"
    "clickup"
    "background-music"
    "obsidian"
    "xpipe"
    "geekbench"
    "geekbench-ai"
    "ollama"
    "xquartz"

    # Tmp
    "ghostty"

  ];

  homebrew.brews = [
    "cava"
    "dockutil"
    "ical-buddy"
    "ifstat"
    {
      name = "sketchybar"; # It's easier to grant permissions through brew than home-manager
      restart_service = false;
      start_service = false;
    }
    "switchaudio-osx"
  ];
}
