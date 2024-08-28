{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    chromedriver
    firefox
    ungoogled-chromium
  ];
}
