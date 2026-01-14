{
  config,
  pkgs,
  lib,
  role,
  ...
}:
let
  isHeadless = role == "headless";
in
{
  # Passwordless sudo for kamushadenes
  security.sudo.extraRules = [
    {
      users = [ "kamushadenes" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
  # GUI security tools (only for desktop systems)
  environment.systemPackages = lib.optionals (!isHeadless) (
    with pkgs; [
      burpsuite
      ngrok
      qFlipper
      wireshark
      yubioath-flutter # replaces yubikey-manager-qt which was removed
      yubikey-personalization-gui
    ]
  );

  # 1Password GUI (only for desktop systems)
  programs._1password-gui.enable = !isHeadless;
  programs._1password-gui.polkitPolicyOwners = lib.mkIf (!isHeadless) [
    config.users.users.kamushadenes.name
  ];

  # SSH server (always enabled)
  services.openssh.enable = true;
}
