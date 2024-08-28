{
  description = "Machine Configuration";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-24.05-darwin";
    };

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nh-darwin = {
      url = "github:ToyVo/nh_darwin";
    };

    home-manager = {
      url = "github:kamushadenes/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:kamushadenes/ragenix/fe5b4e32fdf29c969200163ab4b14711ebdfd443";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
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
        "Kamus-Mac-Studio" = darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = {
            inherit inputs;
            platform = "aarch64-darwin";
          };
          modules = [
            ./darwin.nix
            nh-darwin.nixDarwinModules.prebuiltin
            agenix.darwinModules.default
            home-manager.darwinModules.home-manager
            (
              {
                pkgs,
                config,
                inputs,
                ...
              }:
              {
                home-manager.extraSpecialArgs = {
                  inherit inputs;
                  machine = "Kamus-Mac-Studio";
                };
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.kamushadenes = import ./home.nix;
                home-manager.sharedModules = sharedModules;
              }
            )
          ];
        };
      };

      nixosConfigurations = {
        "nixos" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
            platform = "x86_64-linux";
            hardware = ./nixos/hardware/nixos.nix;
          };
          modules = [
            ./nixos.nix
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager
            (
              {
                pkgs,
                config,
                inputs,
                ...
              }:
              {
                home-manager.extraSpecialArgs = {
                  inherit inputs;
                  machine = "nixos";
                };
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.kamushadenes = import ./home.nix;
                home-manager.sharedModules = sharedModules;
              }
            )
          ];
        };
      };
    };
}
