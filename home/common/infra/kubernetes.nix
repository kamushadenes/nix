{
  pkgs,
  helpers,
  themes,
  ...
}:
{
  home.packages = with pkgs; [
    argocd
    kubebuilder
    kubectl
    kubectx
    kubelogin-oidc
    kubernetes-helm
    kubeseal
    kubeshark
    kubetail
  ];

  programs.k9s = {
    enable = true;

    aliases = {
      aliases = {
        pp = "v1/pods";
        dp = "deployments";
        sec = "v1/secrets";
        jo = "jobs";
        cr = "clusterroles";
        crb = "clusterrolebindings";
        ro = "roles";
        rb = "rolebindings";
        np = "networkpolicies";
      };
    };

    settings = {
      k9s = {
        liveViewAutoRefresh = true;
        refreshRate = 2;
        ui = {
          enableMouse = true;
          skin = "catppuccin_macchiato";
          noIcons = false;
        };
      };
    };

    skins = {
      catppuccin_macchiato = helpers.readYAML (themes.k9sCatppuccin + "/dist/catppuccin-macchiato.yaml");
    };

    hotkey = {
      hotKey = {
        shift-0 = {
          shortCut = "Shift-0";
          description = "Viewing pods";
          command = "pods";
        };
      };
    };

    plugin = {
      fred = {
        shortCut = "Ctrl-L";
        description = "Pod logs";
        scopes = [ "po" ];
        command = "kubectl";
        background = false;
        args = [
          "logs"
          "-f"
          "$NAME"
          "-n"
          "$NAMESPACE"
          "--context"
          "$CLUSTER"
        ];
      };
    };
  };
}
