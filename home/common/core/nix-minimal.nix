# Minimal nix settings for service containers
# Just disables man pages to reduce closure size
# For full nix tools (devbox, nix-tree, nh, etc.), see nix.nix
{ ... }:
{
  manual.manpages.enable = false;
  programs.man.enable = false;
}
