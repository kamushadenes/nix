{
  config,
  helpers,
  ...
}:
{
  programs = {
    bash = {
      enable = true;
      enableVteIntegration = true;
      sessionVariables = helpers.globalVariables.base;

      bashrcExtra = ''
        export PATH="$PATH:{config.home.homeDirectory}/.cargo/bin:${config.home.homeDirectory}/.config/emacs/bin:${config.home.homeDirectory}/.krew/bin:${config.home.homeDirectory}/.config/composer/vendor/bin"
      '';
    };
  };
}
