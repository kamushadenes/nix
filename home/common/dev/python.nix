{
  pkgs,
  ...
}:
let
  tdd-guard-pytest = pkgs.python312Packages.buildPythonPackage rec {
    pname = "tdd-guard-pytest";
    version = "0.1.2";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "nizos";
      repo = "tdd-guard";
      rev = "0f01104ebd2c87956467d89a63cdf7749e7d099f";
      hash = "sha256-YHyScDD7UcodT/tXJD+bHZQke7eJIHFeER/gyDisPo8=";
    };

    sourceRoot = "${src.name}/reporters/pytest";

    build-system = [ pkgs.python312Packages.setuptools ];

    dependencies = [ pkgs.python312Packages.pytest ];

    # Tests require the full tdd-guard setup
    doCheck = false;

    meta = with pkgs.lib; {
      description = "Pytest plugin for TDD Guard - enforces Test-Driven Development principles";
      homepage = "https://github.com/nizos/tdd-guard";
      license = licenses.mit;
    };
  };
in
{
  home.packages = with pkgs; [
    black
    python312
    python312Packages.tkinter
    tdd-guard-pytest
  ];
}
