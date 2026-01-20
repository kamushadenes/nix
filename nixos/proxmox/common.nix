# Common settings for all Proxmox guests (VMs and LXC containers)
# Imported by both vm.nix and lxc.nix
{ config, lib, pkgs, ... }:

{
  # Enable flakes and nix-command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Add trusted users for remote rebuilds
  nix.settings.trusted-users = [ "root" "@wheel" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Base system packages needed for remote management
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    htop
    tmux
  ];

  # Enable SSH for remote management
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Basic networking
  networking = {
    useDHCP = lib.mkDefault true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  # Timezone (can be overridden per-host)
  time.timeZone = lib.mkDefault "America/Sao_Paulo";

  # Locale settings
  i18n.defaultLocale = "en_US.UTF-8";

  # Root user with SSH key access
  users.users.root.openssh.authorizedKeys.keys = [
    # Add your SSH public key here for initial access
    # This will be overridden when you add the machine to nixosConfigurations
  ];

  # System state version
  system.stateVersion = "24.11";
}
