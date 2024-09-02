{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.file = lib.mkIf pkgs.stdenv.isDarwin {
    Dropbox = {
      source = config.lib.file.mkOutOfStoreSymlink "/Volumes/DROPBOX";
      target = "${config.home.homeDirectory}/Dropbox";
    };
  };
}
