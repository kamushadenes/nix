{
  description = "Machine Configuration";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";
    };

    nixpkgs-unstable = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.92.0-3.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:kamushadenes/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #mcp-hub = {
    #  url = "github:ravitemer/mcp-hub";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-unstable,
      lix-module,
      home-manager,
      darwin,
      agenix,
      #mcp-hub,
      ...
    }:
    let
      darwinModules = [
        ./darwin.nix
        agenix.darwinModules.default
        lix-module.nixosModules.default
        home-manager.darwinModules.home-manager
        # https://github.com/NixOS/nixpkgs/issues/402079
        (
          { pkgs, ... }:
          {
            nixpkgs.overlays = [
              (final: prev: {
                nodejs = final.nodejs_22;
                nodejs-slim = final.nodejs-slim_22;
              })
            ];
          }
        )
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

      nixosModules = [
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

      hmModules = [
        agenix.homeManagerModules.default
      ];

      hmDefaults = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.kamushadenes = import ./home.nix;
        sharedModules = hmModules;
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
            modules = darwinModules;
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
            modules = darwinModules;
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
            modules = nixosModules;
          };
      };
    };
}
