{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    burpsuite
    maltego
    ngrok
    qFlipper
    wireshark
    yubikey-manager-qt
    yubikey-personalization-gui
  ];

  programs._1password-gui.enable = true;
  programs._1password-gui.polkitPolicyOwners = [ config.users.users.kamushadenes.name ];

  services.openssh.enable = true;
}
