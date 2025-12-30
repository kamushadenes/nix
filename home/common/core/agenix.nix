{ pkgs, inputs, ... }:

{
  home.packages = with inputs; [
    agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.rage
  ];
}
