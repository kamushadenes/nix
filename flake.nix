{
  description = "Machine Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";
    nixpkgs_2505.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:kamushadenes/ragenix";
      inputs.nixpkgs.follows = "nixpkgs_2505";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      darwin,
      agenix,
      ...
    }:
    let
      # Fetch private submodule from local path with submodules enabled
      # Uses absolute path because flake source is copied to nix store without submodules
      private = builtins.fetchGit {
        url = "file:///Users/kamushadenes/.config/nix/config";
        submodules = true;
        allRefs = true;
      } + "/private";

      # Helper to create Darwin host configurations
      mkDarwinHost =
        {
          machine,
          shared ? false,
          system ? "aarch64-darwin",
        }:
        darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit inputs machine shared private;
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
            platform = system;
          };
          modules = darwinModules;
        };

      # Helper to create NixOS host configurations
      mkNixosHost =
        {
          machine,
          hardware,
          shared ? false,
          system ? "x86_64-linux",
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs machine shared private hardware;
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
            platform = system;
          };
          modules = nixosModules;
        };

      darwinModules = [
        ./darwin.nix
        agenix.darwinModules.default
        home-manager.darwinModules.home-manager
        (
          { pkgs, pkgs-unstable, config, inputs, machine, platform, shared, ... }:
          {
            home-manager = pkgs.lib.mkMerge [
              {
                extraSpecialArgs = {
                  inherit inputs pkgs-unstable machine platform shared private;
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
        (
          { pkgs, pkgs-unstable, config, inputs, machine, platform, shared, private, ... }:
          {
            home-manager = pkgs.lib.mkMerge [
              {
                extraSpecialArgs = {
                  inherit inputs pkgs-unstable machine platform shared private;
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
        studio = mkDarwinHost { machine = "studio.hyades.io"; };
        macbook-m3-pro = mkDarwinHost { machine = "macbook-m3-pro.hyades.io"; shared = true; };
        w-henrique = mkDarwinHost { machine = "w-henrique.hyades.io"; };
      };

      nixosConfigurations = {
        nixos = mkNixosHost {
          machine = "nixos";
          hardware = ./nixos/hardware/nixos.nix;
        };
      };
    };
}
