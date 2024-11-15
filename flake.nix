{
  description = "Machine Configuration";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-24.05-darwin";
    };

    nixpkgs-unstable = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.91.1-1.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nh-darwin = {
      url = "github:ToyVo/nh_darwin";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-unstable,
      lix-module,
      home-manager,
      darwin,
      nh-darwin,
      agenix,
      ...
    }:
    let
      sharedModules = [ agenix.homeManagerModules.default ];
      hmDefaults = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.kamushadenes = import ./home.nix;
        sharedModules = sharedModules;
        backupFileExtension = "hm.bkp";
      };
      hmShared = {
        users.yjrodrigues = import ./home_other.nix;
      };
    in
    {
      darwinConfigurations = {
        studio =
          let
            system = "aarch64-darwin";
            machine = "studio.hyades.io";
            shared = false;
          in
          darwin.lib.darwinSystem {
            system = system;
            specialArgs = {
              inherit inputs;
              inherit machine;
              inherit shared;
              pkgs-unstable = import nixpkgs-unstable {
                inherit system;
                config.allowUnfree = true;
              };
              platform = system;
            };
            modules = [
              ./darwin.nix
              nh-darwin.nixDarwinModules.prebuiltin
              agenix.darwinModules.default
              lix-module.nixosModules.default
              home-manager.darwinModules.home-manager
              (
                {
                  pkgs,
                  pkgs-unstable,
                  config,
                  inputs,
                  machine,
                  platform,
                  shared,
                  ...
                }:
                {
                  home-manager = pkgs.lib.mkMerge [
                    {
                      extraSpecialArgs = {
                        inherit inputs;
                        inherit pkgs-unstable;
                        inherit machine;
                        inherit platform;
                        inherit shared;
                      };
                    }
                    hmDefaults
                    (pkgs.lib.mkIf shared hmShared)
                  ];
                }
              )
            ];
          };
        macbook-m3-pro =
          let
            system = "aarch64-darwin";
            machine = "macbook-m3-pro.hyades.io";
            shared = true;
          in
          darwin.lib.darwinSystem {
            system = system;
            specialArgs = {
              inherit inputs;
              inherit machine;
              inherit shared;
              pkgs-unstable = import nixpkgs-unstable {
                inherit system;
                config.allowUnfree = true;
              };
              platform = system;
            };
            modules = [
              ./darwin.nix
              nh-darwin.nixDarwinModules.prebuiltin
              agenix.darwinModules.default
              lix-module.nixosModules.default
              home-manager.darwinModules.home-manager
              (
                {
                  pkgs,
                  pkgs-unstable,
                  config,
                  inputs,
                  machine,
                  platform,
                  shared,
                  ...
                }:
                {
                  home-manager = pkgs.lib.mkMerge [
                    {
                      extraSpecialArgs = {
                        inherit inputs;
                        inherit pkgs-unstable;
                        inherit machine;
                        inherit platform;
                        inherit shared;
                      };
                    }
                    hmDefaults
                    (pkgs.lib.mkIf shared hmShared)
                  ];
                }
              )
            ];
          };
      };

      nixosConfigurations = {
        nixos =
          let
            system = "x86_64-linux";
            machine = "nixos";
            shared = false;
          in
          nixpkgs.lib.nixosSystem {
            system = system;
            specialArgs = {
              inherit inputs;
              inherit machine;
              inherit shared;
              pkgs-unstable = import nixpkgs-unstable {
                inherit system;
                config.allowUnfree = true;
              };
              platform = system;
              hardware = ./nixos/hardware/nixos.nix;
            };
            modules = [
              ./nixos.nix
              agenix.nixosModules.default
              home-manager.nixosModules.home-manager
              lix-module.nixosModules.default
              (
                {
                  pkgs,
                  pkgs-unstable,
                  config,
                  inputs,
                  machine,
                  shared,
                  ...
                }:
                {
                  home-manager = pkgs.lib.mkMerge [
                    {
                      extraSpecialArgs = {
                        inherit inputs;
                        inherit pkgs-unstable;
                        inherit machine;
                        inherit shared;
                      };
                    }
                    hmDefaults
                    (pkgs.lib.mkIf shared hmShared)
                  ];
                }
              )
            ];
          };
      };
    };
}
