{ pkgs, ... }:

{
  services = {
    # Enable the IPFS service.
    ipfs = {
      enable = true;
      enableGarbageCollection = true;
    };
  };
}
