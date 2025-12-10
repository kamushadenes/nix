{ lib, machine, ... }:
{
  nix = {
    settings = {
      connect-timeout = 5;
      fallback = true;
      substituters = [
        "http://ncps.hyades.io:8501"
        "https://nix-community.cachix.org"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "ncps.hyades.io:/02vviGNLGYhW28GFzmPFupnP6gZ4uDD4G3kRnXuutE="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      trusted-substituters = [
        "http://ncps.hyades.io:8501"
      ];
      trusted-users = [
        "kamushadenes"
      ];
    };
  };
}
