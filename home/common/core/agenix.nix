{ pkgs, inputs, ... }:

{
  home.packages = with inputs; [
    agenix.packages.${pkgs.system}.default
    pkgs.rage
  ];
}
