# Container "hardware" configuration
# Minimal config for Docker/OCI containers - no bootloader, no physical hardware
{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
  ];

  # Container-specific boot settings
  boot.isContainer = true;
  boot.loader.grub.enable = false;

  # Root filesystem (tmpfs in container)
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "mode=0755"
      "size=4G"
    ];
  };

  # Container hostname
  networking.hostName = "claude-sandbox";
}
