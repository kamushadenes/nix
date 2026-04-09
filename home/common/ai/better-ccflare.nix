{
  config,
  lib,
  pkgs,
  packages,
  ...
}:
let
  betterCcflareBin = "${packages.better-ccflare}/bin/better-ccflare";
  dataDir = "${config.home.homeDirectory}/.local/share/better-ccflare";
in
{
  home.packages = [ packages.better-ccflare ];

  # Ensure data directory exists
  home.activation.betterCcflareDataDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${dataDir}"
  '';

  # LaunchAgent for better-ccflare (Darwin)
  launchd.agents.better-ccflare = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      Label = "com.github.tombii.better-ccflare";
      ProgramArguments = [
        betterCcflareBin
        "--serve"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/better-ccflare.out.log";
      StandardErrorPath = "/tmp/better-ccflare.err.log";
      EnvironmentVariables = {
        BETTER_CCFLARE_DB_PATH = "${dataDir}/better-ccflare.db";
        HOME = config.home.homeDirectory;
        PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };

  # Systemd user service (Linux)
  systemd.user.services.better-ccflare = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "better-ccflare - Claude API reverse proxy";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${betterCcflareBin} --serve";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "BETTER_CCFLARE_DB_PATH=${dataDir}/better-ccflare.db"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
