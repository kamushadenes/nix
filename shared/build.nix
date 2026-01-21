{
  config,
  pkgs,
  machine,
  lib,
  platform,
  ...
}:
let
  # Helper to create a Darwin build machine configuration
  mkDarwinBuildMachine = hostName: {
    inherit hostName;
    system = "aarch64-darwin";
    protocol = "ssh-ng";
    maxJobs = 2;
    speedFactor = 2;
    supportedFeatures = [ "big-parallel" ];
    mandatoryFeatures = [ ];
  };

  # Helper to create a Linux build machine configuration
  mkLinuxBuildMachine = hostName: {
    inherit hostName;
    systems = [ "x86_64-linux" "aarch64-linux" ];
    protocol = "ssh-ng";
    maxJobs = 8;
    speedFactor = 4;
    supportedFeatures = [ "big-parallel" "kvm" "nixos-test" ];
    mandatoryFeatures = [ ];
  };

  # Define Darwin build machines (currently disabled - use local builds)
  darwinBuildMachineConfigs = [
  ];

  # Define Linux build machines
  linuxBuildMachineConfigs = [
    { hostName = "aether"; machineName = "aether"; }
  ];

  # Filter out the current machine
  activeDarwinMachines = lib.filter (m: m.machineName != machine) darwinBuildMachineConfigs;
  activeLinuxMachines = lib.filter (m: m.machineName != machine) linuxBuildMachineConfigs;

  # Combine all active build machines
  allBuildMachines =
    (map (m: mkDarwinBuildMachine m.hostName) activeDarwinMachines)
    ++ (map (m: mkLinuxBuildMachine m.hostName) activeLinuxMachines);
  # All hostnames for substituters
  allSubstituterHosts =
    (map (m: m.hostName) activeDarwinMachines)
    ++ (map (m: m.hostName) activeLinuxMachines);
in
{
  nix = {
    # Disable nix.gc in favor of programs.nh.clean
    gc = {
      automatic = false;
      options = "--delete-older-than 30d";
    };

    buildMachines = allBuildMachines;
    # Enable distributed builds when remote builders are configured
    distributedBuilds = allBuildMachines != [];
    extraOptions = ''
      builders-use-substitutes = true
    '';

    optimise = {
      automatic = true;
    };

    settings = {
      substituters = map (h: "ssh-ng://${h}") allSubstituterHosts;
    };
  };
}
