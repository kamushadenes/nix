{ config, ... }:

{
  # Homebrew
  homebrew.enable = false;
  homebrew.user = config.users.users.homebrew.name;

  # Disable auto-update
  homebrew.global.autoUpdate = false;

  # Taps
  homebrew.taps = [
    "caarlos0/tap"
  ];

  # Formulas
  homebrew.brews = [
    "claude-code"
    "gettext"
    "fish"
    "caarlos0/tap/xdg-open-svc" # Remote URL opening over SSH
  ];

  # Cask Args
  homebrew.caskArgs = {
    # Disable quarantine for applications installed by Brew
    no_quarantine = true;
  };
}
