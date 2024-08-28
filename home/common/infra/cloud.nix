{ pkgs, ... }:
{
  programs = {
    awscli = {
      enable = true;
    };
  };

  home.packages = with pkgs; [
    (google-cloud-sdk.withExtraComponents [ google-cloud-sdk.components.gke-gcloud-auth-plugin ])
    steampipe
  ];
}
