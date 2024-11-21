{ ... }:

{
  # Homebrew
  homebrew.enable = true;

  # Disable auto-update
  homebrew.global.autoUpdate = false;

  # Formulas
  homebrew.brews = [
    "gettext"
    "fish"
  ];

  # Cask Args
  homebrew.caskArgs = {
    # Disable quarantine for applications installed by Brew
    no_quarantine = true;
  };
}
