{
  config,
  pkgs,
  machine,
  ...
}:

{
  nix.buildMachines =
    [ ]
    ++ lib.optionals (machine != "studio.hyades.io") [

      {
        hostName = "studio.hyades.io";
        system = "aarch64-darwin";
        protocol = "ssh-ng";
        # if the builder supports building for multiple architectures,
        # replace the previous line by, e.g.
        # systems = ["x86_64-linux" "aarch64-linux"];
        maxJobs = 2;
        speedFactor = 2;
        supportedFeatures = [
          "big-parallel"
        ];
        mandatoryFeatures = [ ];
      }
    ]
    ++ lib.optionals (machine != "macbook-m3-pro.hyades.io") [

      {
        hostName = "mac.hyades.io";
        system = "aarch64-darwin";
        protocol = "ssh-ng";
        maxJobs = 2;
        speedFactor = 2;
        supportedFeatures = [
          "big-parallel"
        ];
        mandatoryFeatures = [ ];
      }
    ]
    ++ lib.optionals (machine != "w-henrique.hyades.io") [

      {
        hostName = "w-henrique.hyades.io";
        system = "aarch64-darwin";
        protocol = "ssh-ng";
        maxJobs = 2;
        speedFactor = 2;
        supportedFeatures = [
          "big-parallel"
        ];
        mandatoryFeatures = [ ];
      }
    ];
  nix.distributedBuilds = true;
  # optional, useful when the builder has a faster internet connection than yours
  nix.extraOptions = ''
    	  builders-use-substitutes = true
    	'';
}
