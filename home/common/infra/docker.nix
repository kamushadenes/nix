{ pkgs, pkgs-unstable, ... }:
{
  home.packages = with pkgs; [
    docker-client
    docker-buildx
    docker-compose
    docker-credential-helpers
    skopeo
    lazydocker
    pkgs-unstable.dive
  ];
}
