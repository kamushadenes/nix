{ pkgs, lib, ... }:
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
    ];
}
