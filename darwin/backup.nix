{ config, pkgs, ... }:
{
  homebrew.taps = [ "garethgeorge/homebrew-backrest-tap" ];

  homebrew.brews = [
    {
      name = "backrest";
      restart_service = false;
      start_service = true;
    }
  ];
}
