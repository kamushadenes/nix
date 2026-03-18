---
paths:
  - "**/*.src.yml"
  - "**/gitops.sh"
  - "**/*.mobileconfig"
  - "**/software-manifest.yml"
  - "**/*fleet*.tf"
---

# FleetDM CLI (fleetctl) Rules

Use `fleetctl` for all Fleet operations. It is already authenticated.

## GitOps Workflow

```bash
fleetctl gitops -f config.yml --dry-run   # Validate before applying
fleetctl gitops -f config.yml             # Apply configuration
```

## Common Operations

- **Queries**: `fleetctl get queries`, `fleetctl query --hosts HOST --query "SELECT ..."`
- **Hosts**: `fleetctl get hosts`
- **Teams**: `fleetctl get teams`
- **Labels**: `fleetctl get labels`
- **Software**: `fleetctl get software`
- **Config**: `fleetctl get config`
- **Enroll secrets**: `fleetctl get enroll_secrets`
- **MDM commands**: `fleetctl get mdm-commands`, `fleetctl get mdm-command-results`

## Apply Configuration

```bash
fleetctl apply -f spec.yml                # One-off import
fleetctl apply -f spec.yml --dry-run      # Validate only
```

## Live Queries

```bash
fleetctl query --hosts host1,host2 --query "SELECT * FROM os_version" --exit
fleetctl query --labels "All Linux" --query "SELECT * FROM uptime" --exit
```

## Run Scripts

```bash
fleetctl run-script --hosts host1 --script-path ./fix.sh
```
