{ config, ... }:

{
  # Homebrew
  homebrew.enable = false;
  homebrew.user = config.users.users.homebrew.name;

  # Disable auto-update
  homebrew.global.autoUpdate = false;

  # Formulas
  homebrew.brews = [
    "claude-code"
    "gettext"
    "fish"
  ];

  # Cask Args
  homebrew.caskArgs = {
    # Disable quarantine for applications installed by Brew
    no_quarantine = true;
  };
}
