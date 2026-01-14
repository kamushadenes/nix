{
  config,
  pkgs,
  machine,
  lib,
  ...
}:
let
  # Helper to create a build machine configuration
  mkBuildMachine = hostName: {
    inherit hostName;
    system = "aarch64-darwin";
    protocol = "ssh-ng";
    maxJobs = 2;
    speedFactor = 2;
    supportedFeatures = [ "big-parallel" ];
    mandatoryFeatures = [ ];
  };

  # Define all build machines with their corresponding machine names
  buildMachineConfigs = [
    { hostName = "studio.hyades.io"; machineName = "studio.hyades.io"; }
    { hostName = "mac.hyades.io"; machineName = "macbook-m3-pro.hyades.io"; }
    { hostName = "w-henrique.hyades.io"; machineName = "w-henrique.hyades.io"; }
  ];

  # Filter out the current machine and create build machine configs
  activeBuildMachines = lib.filter (m: m.machineName != machine) buildMachineConfigs;
in
{
  nix = {
    # Disable nix.gc in favor of programs.nh.clean
    gc = {
      automatic = false;
      options = "--delete-older-than 30d";
    };

    buildMachines = map (m: mkBuildMachine m.hostName) activeBuildMachines;
    # Use mkDefault so linux-builder can override this to true
    distributedBuilds = lib.mkDefault false;
    extraOptions = ''
      builders-use-substitutes = true
    '';

    optimise = {
      automatic = true;
    };

    settings = {
      substituters = map (m: "ssh-ng://${m.hostName}") activeBuildMachines;
    };
  };
}
