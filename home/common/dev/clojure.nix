{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    babashka
    clojure
    leiningen
    cljfmt
    clj-kondo
  ];
}
