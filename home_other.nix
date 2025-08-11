{
  pkgs,
  lib,
  osConfig,
  ...
}:
{
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true;
      initContent = lib.mkMerge [
        (lib.optionals pkgs.stdenv.isDarwin ''
          path+=('${osConfig.homebrew.brewPrefix}')
          export PATH
        '')
      ];
    };
    bash = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true;
      bashrcExtra = ''
        export PATH=$PATH:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin

        export PATH=$PATH:/opt/homebrew/bin

        export PATH=$PATH:/Users/yjrodrigues/.mcuxpressotools/dtc-1.6.1-macos/dtc

        eval "$(/opt/homebrew/bin/brew shellenv)"

        export PATH="/opt/homebrew/opt/python/libexec/bin:$PATH"
      '';
    };
  };

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
}
