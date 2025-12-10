{
  config,
  pkgs,
  machine,
  lib,
  ...
}:

{
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    buildMachines =
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
    distributedBuilds = true;
    extraOptions = ''
      	  builders-use-substitutes = true
      	'';

    optimise = {
      automatic = true;
    };
    settings = {
      substituters =
        [ ]
        ++ lib.optionals (machine != "studio.hyades.io") [
          "ssh-ng://studio.hyades.io"
        ]
        ++ lib.optionals (machine != "macbook-m3-pro.hyades.io") [
          "ssh-ng://mac.hyades.io"
        ]
        ++ lib.optionals (machine != "w-henrique.hyades.io") [
          "ssh-ng://w-henrique.hyades.io"
        ];
    };
  };
}
