{
  description = "Machine Configuration";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-24.05-darwin";
    };

    nixpkgs-unstable = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
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
      home-manager,
      darwin,
      nh-darwin,
      agenix,
      ...
    }:
    let
      sharedModules = [ agenix.homeManagerModules.default ];
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
                  home-manager.extraSpecialArgs = {
                    inherit inputs;
                    inherit pkgs-unstable;
                    inherit machine;
                    inherit platform;
                    inherit shared;
                  };
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.users.kamushadenes = import ./home.nix;
                  home-manager.users.yjrodrigues = import ./home_other.nix;
                  home-manager.sharedModules = sharedModules;
                  home-manager.backupFileExtension = "hm.bkp";
                }
              )
            ];
          };
        MacBook-M3-Pro =
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
                  home-manager.extraSpecialArgs = {
                    inherit inputs;
                    inherit pkgs-unstable;
                    inherit machine;
                    inherit platform;
                    inherit shared;
                  };
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.users.kamushadenes = import ./home.nix;
                  home-manager.users.yjrodrigues = import ./home_other.nix;
                  home-manager.sharedModules = sharedModules;
                  home-manager.backupFileExtension = "hm.bkp";
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
          in
          nixpkgs.lib.nixosSystem {
            system = system;
            specialArgs = {
              inherit inputs;
              inherit machine;
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
              (
                {
                  pkgs,
                  pkgs-unstable,
                  config,
                  inputs,
                  machine,
                  ...
                }:
                {
                  home-manager.extraSpecialArgs = {
                    inherit inputs;
                    inherit pkgs-unstable;
                    inherit machine;
                  };
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.users.kamushadenes = import ./home.nix;
                  home-manager.sharedModules = sharedModules;
                  home-manager.backupFileExtension = "hm.bkp";
                }
              )
            ];
          };
      };
    };
}
