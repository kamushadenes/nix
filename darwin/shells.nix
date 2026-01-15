{ ... }:
{
  imports = [ ../shared/shells.nix ];

  # Brews
  homebrew.brews = [ "mosh" ];
}
