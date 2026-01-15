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

  # Session creation script
  createSessionScript = pkgs.writeShellScript "mutagen-create-sessions" ''
    set -e
    export PATH="${pkgs.openssh}/bin:$PATH"

    # Ensure daemon is running
    ${lib.getExe mutagen} daemon start 2>/dev/null || true

    # Create sessions for each project (if they don't exist)
    ${lib.concatMapStrings (project: ''
      if ! ${lib.getExe mutagen} sync list 2>/dev/null | grep -q "Name: ${project}"; then
        echo "Creating session for ${project}..."
        ${lib.getExe mutagen} sync create \
          "${projectsPath}/${project}" \
          "${hubHost}:${hubPath}/${project}" \
          --name="${project}" || echo "Failed to create session for ${project}"
      fi
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
    };
  };

  # Activation script to create sync sessions (spoke machines only)
  home.activation.mutagenSessions = lib.mkIf (!isHub) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${createSessionScript}
    ''
  );
}
