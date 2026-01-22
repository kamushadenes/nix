{
  config,
  pkgs,
  lib,
  role,
  ...
}:
let
  isHeadless = role == "headless";
  isMinimal = role == "minimal";
  isServer = isHeadless || isMinimal;
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
  environment.systemPackages = lib.optionals (!isServer) (
    with pkgs; [
      burpsuite
      ngrok
      qFlipper
      wireshark
      yubioath-flutter
    ]
  );

  # 1Password GUI (only for desktop systems)
  programs._1password-gui.enable = !isServer;
  programs._1password-gui.polkitPolicyOwners = lib.mkIf (!isServer) [
    config.users.users.kamushadenes.name
  ];

  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowPing = true;
    logRefusedConnections = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPortRanges = [
      { from = 60001; to = 60999; } # mosh
    ];
  };

  # Mosh server (mobile shell)
  programs.mosh.enable = true;

  # SSH server with hardening
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = lib.mkDefault "no";
      X11Forwarding = false;
      MaxAuthTries = 3;
      # Modern crypto only
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
      ];
      KexAlgorithms = [
        "mlkem768x25519-sha256"
        "sntrup761x25519-sha512"
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
      ];
    };
    extraConfig = ''
      ClientAliveInterval 300
      ClientAliveCountMax 3
    '';
  };

  # Fail2ban for SSH protection
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    ignoreIP = [
      "127.0.0.0/8"
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
      "100.64.0.0/10" # Tailscale CGNAT range
    ];
    jails.sshd.settings = {
      enabled = true;
      maxretry = 3;
      bantime = lib.mkIf isHeadless "24h"; # Longer ban for servers
    };
  };

  # Kernel security hardening
  boot.kernel.sysctl = {
    # Prevent IP spoofing
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    # Disable IP source routing
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    # Disable ICMP redirects
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    # Enable SYN flood protection
    "net.ipv4.tcp_syncookies" = 1;
  };
}
