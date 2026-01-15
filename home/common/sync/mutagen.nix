{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  machine,
  ...
}:
let
  mutagen = pkgs-unstable.mutagen;

  # Projects to sync
  projects = [
    "Altinity"
    "Iniciador"
    "Hadenes"
    "Personal"
    "Hyades"
  ];

  # Platform-specific base path
  projectsPath =
    if pkgs.stdenv.isDarwin then
      "/Users/kamushadenes/Dropbox/Projects"
    else
      "/home/kamushadenes/Dropbox/Projects";

  # Hub configuration
  hubHost = "aether";
  hubPath = "/home/kamushadenes/Dropbox/Projects";

  # This machine is the hub (doesn't need sync sessions to itself)
  isHub = machine == "aether";

  # Ignore patterns for sync
  ignorePatterns = [
    "node_modules"
    "__pycache__"
    ".pytest_cache"
    ".mypy_cache"
    ".tox"
    ".nox"
    "*.pyc"
    ".DS_Store"
    "*.swp"
    "*.swo"
    ".direnv"
    "result"
    ".devenv"
    "vendor"
    "target"
    "dist"
    "build"
    ".next"
    ".nuxt"
    ".output"
    ".cache"
    ".parcel-cache"
    "coverage"
    ".nyc_output"
    ".terraform"
    "*.egg-info"
  ];

  # Generate mutagen.yml content
  mutagenYaml = pkgs.writeText "mutagen.yml" ''
    sync:
      defaults:
        mode: two-way-safe
        ignore:
          vcs: true
          paths:
${lib.concatMapStrings (p: "            - \"${p}\"\n") ignorePatterns}
        permissions:
          defaultFileMode: 0644
          defaultDirectoryMode: 0755
  '';

  # Shell function to create sync sessions
  createSessionsFunction = ''
    # Ensure daemon is running
    mutagen daemon start 2>/dev/null; or true

    # Create sessions for each project (if they don't exist)
    ${lib.concatMapStrings (project: ''
    if not mutagen sync list 2>/dev/null | grep -q "Name: ${project}"
      echo "Creating session for ${project}..."
      mutagen sync create \
        "${projectsPath}/${project}" \
        "${hubHost}:${hubPath}/${project}" \
        --name="${project}"
    end
    '') projects}
  '';
in
{
  home.packages = [ mutagen ];

  # Mutagen global config
  home.file.".mutagen.yml".source = mutagenYaml;

  # Systemd user service for mutagen daemon (Linux only)
  systemd.user.services.mutagen = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Mutagen daemon";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe mutagen} daemon run";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # LaunchAgent for mutagen daemon (Darwin only)
  launchd.agents.mutagen = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      Label = "io.mutagen.daemon";
      ProgramArguments = [
        "${lib.getExe mutagen}"
        "daemon"
        "run"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/mutagen.out.log";
      StandardErrorPath = "/tmp/mutagen.err.log";
      EnvironmentVariables = {
        PATH = "${pkgs.openssh}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };

  # Fish function to create sync sessions (spoke machines only)
  programs.fish.functions.mutagen-setup = lib.mkIf (!isHub) {
    description = "Create Mutagen sync sessions to hub";
    body = createSessionsFunction;
  };
}
