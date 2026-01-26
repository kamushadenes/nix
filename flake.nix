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

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
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
      nixos-generators,
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

      # Proxmox cluster nodes for daemon LXCs and pct commands
      # Maps node name -> Proxmox host IP (for SSH access as root)
      pveNodes = {
        pve1 = "10.23.5.10";
        pve2 = "10.23.5.11";
        pve3 = "10.23.5.12";
      };

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

      # Helper to create Proxmox VM/LXC host configurations
      # These hosts can optionally use ephemeral tmpfs root with configurable persistence
      mkProxmoxHost =
        {
          machine,
          hardware,
          role ? "headless",
          shared ? false,
          persistence ? true, # Set to false for LXC with persistent root (no bind mounts needed)
          extraPersistPaths ? [ ],
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
          modules = nixosModules ++ (if persistence then [
            ./nixos/proxmox/persistence.nix
            ({ ... }: {
              proxmox.persistence.extraPaths = extraPersistPaths;
            })
          ] else []);
        };

      # Helper to create daemon LXCs that run on all Proxmox nodes
      # Generates: { daemon-pve1 = ...; daemon-pve2 = ...; daemon-pve3 = ...; }
      mkDaemonLXCs = { name, hardware, role ? "minimal", extraPersistPaths ? [] }:
        builtins.listToAttrs (map (node: {
          name = "${name}-${node}";
          value = mkProxmoxHost {
            machine = "${name}-${node}";
            hardware = hardware node;  # Function that takes node name
            inherit role extraPersistPaths;
          };
        }) (builtins.attrNames pveNodes));

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
              hmDarwinRoot
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

      # Darwin-specific home-manager config for root (for nix remote builds)
      hmDarwinRoot = {
        users.root = import ./home_root.nix;
      };

      hmShared = {
        users.yjrodrigues = import ./home_other.nix;
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

        # Atuin shell history sync server (LXC)
        atuin = mkProxmoxHost {
          machine = "atuin";
          hardware = ./nixos/hardware/atuin.nix;
          role = "minimal";
          extraPersistPaths = [ "/var/lib/atuin" ];
        };

        # Mosquitto MQTT broker (LXC) for Home Assistant
        mqtt = mkProxmoxHost {
          machine = "mqtt";
          hardware = ./nixos/hardware/mqtt.nix;
          role = "minimal";
          extraPersistPaths = [ "/var/lib/mosquitto" ];
        };

        # Zigbee2MQTT coordinator (LXC) for Home Assistant
        zigbee2mqtt = mkProxmoxHost {
          machine = "zigbee2mqtt";
          hardware = ./nixos/hardware/zigbee2mqtt.nix;
          role = "minimal";
          extraPersistPaths = [ "/var/lib/zigbee2mqtt" ];
        };

        # ESPHome builder and interface (LXC) for Home Assistant
        esphome = mkProxmoxHost {
          machine = "esphome";
          hardware = ./nixos/hardware/esphome.nix;
          role = "minimal";
          extraPersistPaths = [ "/var/lib/esphome" "/var/lib/docker" ];
        };

        # Nix Cache Proxy Server (ncps) - local binary cache with NFS storage
        ncps = mkProxmoxHost {
          machine = "ncps";
          hardware = ./nixos/hardware/ncps.nix;
          role = "minimal";
          extraPersistPaths = [ "/var/lib/docker" ]; # Cache on NFS, only Docker state local
        };

        # Proxmox VM/LXC examples (uncomment after deploying image):
        #
        # 1. Build images: rebuild --proxmox
        # 2. Upload to Proxmox and boot VM/container
        # 3. Create hardware config: nixos/hardware/<name>.nix
        # 4. Uncomment and customize below:
        #
        # my-postgres-vm = mkProxmoxHost {
        #   machine = "my-postgres-vm";
        #   hardware = ./nixos/hardware/my-postgres-vm.nix;
        #   role = "headless";  # or "workstation"
        #   extraPersistPaths = [ "/var/lib/postgresql" ];
        # };
        #
        # 5. Deploy: rebuild my-postgres-vm
      } // (mkDaemonLXCs {
        # Cloudflare Tunnel daemon - runs on all Proxmox nodes for HA
        # All instances share the same tunnel token (they're connectors to the same tunnel)
        name = "cloudflared";
        hardware = node: ./nixos/hardware/cloudflared-${node}.nix;
        # No extraPersistPaths - token-based tunnels have no persistent state
      }) // (mkDaemonLXCs {
        # Tailscale subnet router daemon - runs on all Proxmox nodes for HA
        # Unlike cloudflared, each node has its OWN state (unique machine identity)
        # pve2/pve3: Create LXCs and auth before deploying (see hardware config TODOs)
        name = "tailscale";
        hardware = node: ./nixos/hardware/tailscale-${node}.nix;
        extraPersistPaths = [ "/var/lib/tailscale" ];
      });

      # Proxmox image builders
      # Build with: rebuild --proxmox-vm or rebuild --proxmox-lxc
      packages.x86_64-linux = {
        # BROKEN: VMA format fails with qemu vma bug:
        # "vma_writer_close failed vma_queue_write: write error - Invalid argument"
        # Kept for future reference when upstream fixes the issue.
        proxmox-vm = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          format = "proxmox";
          modules = [ ./nixos/proxmox/vm.nix ];
        };

        # Workaround: use qcow2 format and import with:
        #   qm importdisk <vmid> nixos-proxmox-vm-qcow2-*.qcow2 <storage>
        proxmox-vm-qcow2 = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          format = "qcow";
          modules = [ ./nixos/proxmox/vm.nix ];
        };
        proxmox-lxc = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          format = "proxmox-lxc";
          modules = [ ./nixos/proxmox/lxc.nix ];
        };
      };
    };
}
