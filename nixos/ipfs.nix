{ pkgs, ... }:

{
  services = {
    # Enable the IPFS service.
    kubo = {
      enable = true;
    };
  };
}
