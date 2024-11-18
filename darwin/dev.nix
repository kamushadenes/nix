{ pkgs, ... }:

{
  homebrew.brews = [
    "qemu"
  ];

  # Casks
  homebrew.casks = [
    "arduino-ide"
    "gitkraken"
    "imhex"
    "lens"
    "mqtt-explorer"
  ];
}
