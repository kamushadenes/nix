{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    arduino-ide
    imhex
    insomnia
    lens
    postman
  ];
}
