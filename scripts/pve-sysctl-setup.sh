#!/usr/bin/env bash
# pve-sysctl-setup.sh - Configure sysctl settings on Proxmox nodes
#
# This script sets up sysctl configurations required for LXC containers
# running services like cloudflared, tailscale, etc.
#
# Usage:
#   ssh root@pve1 < scripts/pve-sysctl-setup.sh
#   # or
#   scp scripts/pve-sysctl-setup.sh root@pve1:/tmp/ && ssh root@pve1 /tmp/pve-sysctl-setup.sh

set -euo pipefail

SYSCTL_CONF="/etc/sysctl.d/99-lxc-services.conf"

echo "==> Configuring sysctl settings for LXC services..."

# Create sysctl configuration file
cat > "$SYSCTL_CONF" << 'EOF'
# Sysctl settings for LXC containers running network services
# Applied to Proxmox host - affects all containers

# UDP buffer sizes for cloudflared and other tunnel services
# Required for QUIC protocol performance
net.core.rmem_max = 7500000
net.core.wmem_max = 7500000

# Allow unprivileged ICMP (ping) for cloudflared ICMP proxy
# Range: min_gid max_gid (0 to max allows all groups)
net.ipv4.ping_group_range = 0 2147483647

# Optional: Increase connection tracking for busy nodes
# Uncomment if needed:
# net.netfilter.nf_conntrack_max = 262144
EOF

echo "==> Created $SYSCTL_CONF"

# Apply settings immediately
echo "==> Applying sysctl settings..."
sysctl -p "$SYSCTL_CONF"

# Verify settings
echo ""
echo "==> Current values:"
echo "    net.core.rmem_max = $(sysctl -n net.core.rmem_max)"
echo "    net.core.wmem_max = $(sysctl -n net.core.wmem_max)"
echo "    net.ipv4.ping_group_range = $(sysctl -n net.ipv4.ping_group_range)"

echo ""
echo "==> Done! Settings will persist across reboots."
