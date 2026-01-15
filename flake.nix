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

    claudebox = {
      # Using fork with macOS ~/.claude write permission fix
      # PR: https://github.com/numtide/claudebox/pull/1
      url = "github:kamushadenes/claudebox";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      darwin,
      agenix,
      claudebox,
      ...
    }:
    let
      # Fetch private submodule from local path with submodules enabled
      # Uses HOME env var for portability (requires --impure flag)
      # Uses ref="main" instead of allRefs=true to avoid exposing entire git history
      private = builtins.fetchGit {
        url = "file://${builtins.getEnv "HOME"}/.config/nix/config";
        submodules = true;
        ref = "main";
      } + "/private";

      # Helper to create Darwin host configurations
      mkDarwinHost =
        {
          machine,
          role ? "workstation",
          shared ? false,
          system ? "aarch64-darwin",
        }:
        darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit inputs machine shared private role;
            claudebox = claudebox.packages.${system}.default;
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
          role ? "workstation",
          shared ? false,
          system ? "x86_64-linux",
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs machine shared private hardware role;
            claudebox = claudebox.packages.${system}.default;
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
          { pkgs, pkgs-unstable, config, inputs, machine, platform, shared, role, claudebox, ... }:
          {
            home-manager = pkgs.lib.mkMerge [
              {
                extraSpecialArgs = {
                  inherit inputs pkgs-unstable machine platform shared private role claudebox;
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
          { pkgs, pkgs-unstable, config, inputs, machine, platform, shared, private, role, claudebox, ... }:
          {
            home-manager = pkgs.lib.mkMerge [
              {
                extraSpecialArgs = {
                  inherit inputs pkgs-unstable machine platform shared private role claudebox;
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

      # Helper to create Docker container images using dockerTools
      mkDockerImage =
        { system }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        in
        import ./docker/image.nix {
          inherit pkgs pkgs-unstable system;
          lib = pkgs.lib;
          claudebox = claudebox.packages.${system}.default or null;
        };
    in
    {
      darwinConfigurations = {
        studio = mkDarwinHost {
          machine = "studio.hyades.io";
          role = "workstation";
        };
        macbook-m3-pro = mkDarwinHost {
          machine = "macbook-m3-pro.hyades.io";
          role = "workstation";
          shared = true;
        };
        w-henrique = mkDarwinHost {
          machine = "w-henrique.hyades.io";
          role = "workstation";
        };
      };

      nixosConfigurations = {
        nixos = mkNixosHost {
          machine = "nixos";
          role = "workstation";
          hardware = ./nixos/hardware/nixos.nix;
        };
        aether = mkNixosHost {
          machine = "aether";
          role = "headless";
          hardware = ./nixos/hardware/aether.nix;
        };
      };

      # Docker images for container-based development
      packages = {
        x86_64-linux.docker = mkDockerImage { system = "x86_64-linux"; };
        aarch64-linux.docker = mkDockerImage { system = "aarch64-linux"; };
      };
    };
}
