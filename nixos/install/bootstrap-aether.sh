#!/usr/bin/env bash
# Bootstrap script for aether.hyades.io NixOS installation
#
# This script prepares a bare-metal system for NixOS installation:
# - Partitions disks (BIOS/msdos)
# - Creates RAID1 array across /dev/sd{a,b}
# - Sets up LUKS encryption
# - Creates tmpfs root with persistent /nix
# - Installs Nix and NixOS tools
#
# WARNING: This script FORMATS DISKS. Run only on the target remote machine.
# Usage: Boot into rescue/live system, copy this script, run manually.

set -e -u -o pipefail -x

lsblk

# Undo any previous changes.
# This allows me to re-run the script many times over
set +e
umount -R /mnt
cryptsetup close cryptroot
vgchange -an
set -e

# Prevent mdadm from auto-assembling any preexisting arrays.
# Otherwise mdadm might detect existing raid signatures after
# partitioning, and start reassembling the array.
mdadm --stop --scan
echo 'AUTO -all
ARRAY <ignore> UUID=00000000:00000000:00000000:00000000' >/etc/mdadm/mdadm.conf

# Partitioning
for disk in /dev/sd?; do
	# This is a BIOS system, so let's avoid GPT
	# Also we only have 2 partitions, so ...
	parted --script --align=optimal "$disk" -- mklabel msdos
	# The boot partition(s)
	parted --script --align=optimal "$disk" -- mkpart primary ext4 1M 1G
	parted --script --align=optimal "$disk" -- set 1 boot on
	# The rest
	parted --script --align=optimal "$disk" -- mkpart primary ext4 1GB '100%'
done

# Reload partition tables.
partprobe || :
# Wait for all partitions to show up
udevadm settle --timeout=5s --exit-if-exists=/dev/sda1
udevadm settle --timeout=5s --exit-if-exists=/dev/sda2
udevadm settle --timeout=5s --exit-if-exists=/dev/sdb1
udevadm settle --timeout=5s --exit-if-exists=/dev/sdb2

# Wipe any previous RAID signatures
mdadm --zero-superblock --force /dev/sda2
mdadm --zero-superblock --force /dev/sdb2

# Create the RAID array
# This is the first hairy bit.
# - make sure "name" matches the device name
# - make sure "homehost" matches what your hostname will be after setup
mdadm --create --run --verbose \
	/dev/md0 \
	--name=md0 \
	--level=raid1 --raid-devices=2 \
	--homehost=aether.hyades.io \
	/dev/sda2 \
	/dev/sdb2

# Remove traces from preexisting filesystems etc.
vgchange -an
wipefs -a /dev/md0

# Disable RAID recovery for now
echo 0 >/proc/sys/dev/raid/speed_limit_max

# Set up encryption
# At this point, the script will ask for the LUKS passphrase _twice_
cryptsetup -q -v luksFormat /dev/md0
cryptsetup -q -v open /dev/md0 cryptroot

# Create filesystems
# We'll make heavy use of labels to identify the FS' later
mkfs.ext4 -F -L boot0 /dev/sda1
mkfs.ext4 -F -L boot1 /dev/sdb1
mkfs.ext4 -F -L nix -m 0 /dev/mapper/cryptroot

# Refresh disk/by-uuid entries
udevadm trigger
udevadm settle --timeout=5 --exit-if-exists=/dev/disk/by-label/nix

# Mount filesystems
mount -t tmpfs none /mnt

# Create & mount additional mount points
mkdir -pv /mnt/{boot,boot-fallback,nix,etc/{nixos,ssh},var/{lib,log},srv}

mount /dev/disk/by-label/boot0 /mnt/boot
mount /dev/disk/by-label/boot1 /mnt/boot-fallback
mount /dev/disk/by-label/nix /mnt/nix

# Create & mount directories for persistence
mkdir -pv /mnt/nix/{secret/initrd,persist/{etc/{nixos,ssh},var/{lib,log},srv}}
chmod 0700 /mnt/nix/secret

mount -o bind /mnt/nix/persist/etc/nixos /mnt/etc/nixos
mount -o bind /mnt/nix/persist/var/log /mnt/var/log

# Install Nix
apt-get update
apt-get install -y sudo
mkdir -p /etc/nix
echo "build-users-group =" >>/etc/nix/nix.conf
curl -sSL https://nixos.org/nix/install | sh
set +u +x # sourcing this may refer to unset variables that we have no control over
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
set -u -x

nix-channel --add https://nixos.org/channels/nixos-unstable nixpkgs
nix-channel --update

# Getting NixOS installation tools
nix-env -iE "_: with import <nixpkgs/nixos> { configuration = {}; }; with config.system.build; [ nixos-generate-config nixos-install ]"

# Generated initrd SSH host key
ssh-keygen -t ed25519 -N "" -C "" -f /mnt/nix/secret/initrd/ssh_host_ed25519_key
