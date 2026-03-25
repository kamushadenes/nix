# Documentation

Technical documentation for this Nix flake configuration.

## Pages

| Document                              | Description                                                                                |
| ------------------------------------- | ------------------------------------------------------------------------------------------ |
| [Architecture](./architecture.md)     | Data flow, layers, specialArgs, Proxmox persistence model, secrets, binary cache           |
| [Module Reference](./modules.md)      | Complete catalog of all 110+ modules across home-manager, Darwin, NixOS, and shared layers |
| [Service Reference](./services.md)    | Every Proxmox LXC service and NixOS machine: ports, secrets, persistence, health checks    |
| [Operations Runbook](./operations.md) | Step-by-step procedures for deployment, machine provisioning, secrets, troubleshooting     |

## Quick Links

- **Add a new LXC**:
  [Operations > Adding a New Proxmox LXC Container](./operations.md#adding-a-new-proxmox-lxc-container)
- **Add a new module**:
  [Modules > Adding a New Module](./modules.md#adding-a-new-module)
- **Understand the role system**:
  [Architecture > Home-Manager Layer](./architecture.md#home-manager-layer)
- **Check service ports**:
  [Services > Summary Table](./services.md#summary-table)
- **Troubleshoot a failed rebuild**:
  [Operations > Troubleshooting](./operations.md#troubleshooting-procedures)
