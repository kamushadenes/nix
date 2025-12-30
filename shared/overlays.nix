# Shared overlays for Darwin and NixOS
{
  # Lix package overlay - replaces certain packages with their Lix equivalents
  lixOverlay = final: prev: {
    inherit (prev.lixPackageSets.stable)
      nixpkgs-review
      nix-eval-jobs
      nix-fast-build
      colmena
      ;
  };
}
