{ pkgs, pkgs-unstable, lib, ... }:
let
  # TDD Guard for Linux - on macOS it's installed via homebrew cask
  tdd-guard = pkgs.buildNpmPackage rec {
    pname = "tdd-guard";
    version = "1.1.0";

    src = pkgs.fetchFromGitHub {
      owner = "nizos";
      repo = "tdd-guard";
      rev = "v${version}";
      hash = "sha256-NAg0suZxtLihkSU6r6VwBn++LYXvh84VsHTVgwFet0U=";
    };

    npmDepsHash = "sha256-jSxvYFlhZv/2TfKFt749PxOffhvcwDikCuqwCm5Xkiw=";

    # Build the TypeScript code
    npmBuildScript = "build";

    # Remove broken symlinks from monorepo workspace structure
    postInstall = ''
      find $out -xtype l -delete
    '';

    meta = with lib; {
      description = "Automated TDD enforcement tool for Claude Code";
      homepage = "https://github.com/nizos/tdd-guard";
      license = licenses.mit;
      mainProgram = "tdd-guard";
    };
  };

  # TDD Guard Vitest reporter for TypeScript projects
  tdd-guard-vitest = pkgs.buildNpmPackage rec {
    pname = "tdd-guard-vitest";
    version = "0.1.6";

    src = pkgs.fetchFromGitHub {
      owner = "nizos";
      repo = "tdd-guard";
      rev = "0f01104ebd2c87956467d89a63cdf7749e7d099f";
      hash = "sha256-YHyScDD7UcodT/tXJD+bHZQke7eJIHFeER/gyDisPo8=";
    };

    sourceRoot = "${src.name}/reporters/vitest";

    npmDepsHash = "sha256-MxRnFcpzFz2VCmA8F4NmL+k6ctwNdOL3B/XHV7QTejQ=";

    # Build the TypeScript code
    npmBuildScript = "build";

    meta = with lib; {
      description = "TDD Guard reporter for Vitest - enforces TDD principles in TypeScript projects";
      homepage = "https://github.com/nizos/tdd-guard";
      license = licenses.mit;
    };
  };
in
{
  home.packages = with pkgs;
    [
      bun
      nodejs
      typescript
      yarn-berry
    ]
    # TDD Guard installed via npm on Linux (homebrew cask on macOS)
    ++ lib.optionals (!stdenv.isDarwin) [
      tdd-guard
      tdd-guard-vitest
    ];

  # Install task-master-ai globally via npm to user-local prefix
  # PATH is configured via shell-common.nix pathAdditions
  # Note: buildNpmPackage fails due to complex peer dependencies, so we use activation hook
  # npm global packages go to ~/.npm-global, which should be in PATH via shell config
  home.activation.installTaskMasterAi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    export PATH="${pkgs.nodejs}/bin:$PATH"
    run mkdir -p "$NPM_CONFIG_PREFIX"

    # Only install if not already installed or outdated
    CURRENT_VERSION=$("$NPM_CONFIG_PREFIX/bin/task-master" --version 2>/dev/null | head -1 || echo "none")
    if [[ "$CURRENT_VERSION" != *"0.42.0"* ]]; then
      run ${pkgs.nodejs}/bin/npm install -g task-master-ai@0.42.0 --prefix="$NPM_CONFIG_PREFIX" 2>&1 || true
    fi
  '';
}
