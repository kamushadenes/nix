{ pkgs, ... }:

{
  imports = [ ../shared/shells.nix ];

  environment.systemPackages = with pkgs; [ sudo ];
}
