{ config, pkgs, pkgs-unstable, lib, ... }:
let
  # Playwriter - thin wrapper around npx (updates automatically)
  playwriter = pkgs.writeShellScriptBin "playwriter" ''
    exec npx -y playwriter@latest "$@"
  '';
  # CCS - Claude Code Switch: universal AI profile manager
  ccs = pkgs.writeShellScriptBin "ccs" ''
    exec npx -y @kaitranntt/ccs@latest "$@"
  '';
in
{
  home.packages = with pkgs;
    [
      bun
      nodejs
      typescript
      yarn-berry
      playwriter
      ccs
    ];


}
