{
  lib,
  pkgs,
  config,
  ...
}:
let
  uploadToCache = pkgs.writeShellScript "upload-to-cache" ''
    set -f
    export IFS=' '
    echo "Uploading to NCPS:" $OUT_PATHS
    ${config.nix.package}/bin/nix copy --to 'https://ncps.hyades.io' $OUT_PATHS || true
  '';
in
{
  nix = {
    settings = {
      connect-timeout = 5;
      fallback = true;
      substituters = [
        "https://ncps.hyades.io"
        "https://nix-community.cachix.org"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "ncps.hyades.io:/02vviGNLGYhW28GFzmPFupnP6gZ4uDD4G3kRnXuutE="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      trusted-substituters = [
        "https://ncps.hyades.io"
      ];
      trusted-users = [
        "kamushadenes"
      ];
      post-build-hook = uploadToCache;
    };
  };
}
