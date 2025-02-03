{ ... }:

{
  services = {
    # Auto upgrade nix package and the daemon service.
    nix-daemon = {
      enable = true;
    };
  };

  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
  };
}
