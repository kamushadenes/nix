{ pkgs, ... }:

{
  # Casks
  homebrew.casks = [
    "arc"
    "chromedriver"
    "eloston-chromium"
    "firefox"
    "orion"
  ];

  environment.systemPackages = with pkgs; [
    # Launch Eloston Chromium (Ungoogled) with the correct flags.
    (writeScriptBin "chromium" ''
      #!/bin/bash
      exec /Applications/Chromium.app/Contents/MacOS/Chromium $@
    '')
  ];
}
