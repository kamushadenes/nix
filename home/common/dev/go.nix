{ pkgs, pkgs-unstable, ... }:
let
  godoc-mcp = pkgs.buildGoModule rec {
    pname = "godoc-mcp";
    version = "latest";

    src = pkgs.fetchFromGitHub {
      owner = "mrjoshuak";
      repo = "godoc-mcp";
      rev = "3296b67e5d374246e84040d4a888eda787a9d195";
      hash = "sha256-obhMD8e5SYakpcImX5obWAqNtXfiT+aFond8wKGnhDg=";
    };

    vendorHash = null;
    preBuild = ''
      export GOPROXY=""
      go mod vendor
    '';

    meta = with pkgs.lib; {
      description = "MCP server for efficient Go documentation access";
      homepage = "https://github.com/mrjoshuak/godoc-mcp";
      license = licenses.mit;
      mainProgram = "godoc-mcp";
    };
  };

  tdd-guard-go = pkgs.buildGoModule rec {
    pname = "tdd-guard-go";
    version = "latest";

    src = pkgs.fetchFromGitHub {
      owner = "nizos";
      repo = "tdd-guard";
      rev = "0f01104ebd2c87956467d89a63cdf7749e7d099f";
      hash = "sha256-YHyScDD7UcodT/tXJD+bHZQke7eJIHFeER/gyDisPo8=";
    };

    vendorHash = null;

    # Point to the subdirectory containing main.go
    modRoot = "reporters/go";
    subPackages = [ "cmd/tdd-guard-go" ];

    meta = with pkgs.lib; {
      description = "TDD Guard reporter for Go";
      homepage = "https://github.com/nizos/tdd-guard";
      mainProgram = "tdd-guard-go";
    };
  };
in
{
  programs.go = {
    enable = true;
  };

  home.packages = with pkgs; [
    cobra-cli
    pkgs-unstable.gopls
    pkgs-unstable.golangci-lint
    pkgs-unstable.govulncheck
    pkgs-unstable.gotestsum
    pkgs-unstable.go-outline
    pkgs-unstable.wails

    godoc-mcp
    tdd-guard-go
  ];
}
