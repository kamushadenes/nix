{ pkgs, helpers, ... }:
{
  programs = {
    bash = {
      enable = true;
      enableVteIntegration = true;
      sessionVariables = helpers.globalVariables.base;
    };
  };
}
