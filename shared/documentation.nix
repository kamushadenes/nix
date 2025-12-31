# Cross-platform documentation settings
# Shared between Darwin and NixOS
{ ... }:
{
  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
  };
}
