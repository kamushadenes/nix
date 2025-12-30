{
  description = "Machine Configuration";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";
    };

    nixpkgs_2505 = {
      url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";
    };

    nixpkgs-unstable = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };

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

    #mcp-hub = {
    #  url = "github:ravitemer/mcp-hub";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      darwin,
      agenix,
      #mcp-hub,
      ...
    }:
    let
      # Fetch private submodule with git submodules enabled
      private = builtins.fetchGit {
        url = "file://${builtins.toString ./.}";
        submodules = true;
        allRefs = true;
      } + "/private";
      darwinModules = [
        ./darwin.nix
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
              inherit private;
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
              inherit private;
              pkgs-unstable = import nixpkgs-unstable {
                inherit system;
                config.allowUnfree = true;
              };
              platform = system;
            };
            modules = darwinModules;
          };
        w-henrique =
          let
            system = "aarch64-darwin";
            machine = "w-henrique.hyades.io";
            shared = false;
          in
          darwin.lib.darwinSystem {
            system = system;
            specialArgs = {
              inherit inputs;
              inherit machine;
              inherit shared;
              inherit private;
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
