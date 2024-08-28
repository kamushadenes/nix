{ pkgs, config, ... }:
let
  gitSquash = pkgs.fetchFromGitHub {
    owner = "sheerun";
    repo = "git-squash";
    rev = "e87fb1d410edceec3670101e2cf89297ecab5813";
    hash = "sha256-yvufKIwjP7VcIzLi8mE228hN4jmaqk90c8oxJtkXEP8=";
  };

  catppuccinDelta = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "delta";
    rev = "b88f87aedbeb7dc74c38831cf385819b69b78cbe";
    hash = "sha256-/zLkxfpTkZ744hUNANFmm96q81ydFM7EcxOj+0GoaGU=";
  };
in
{
  home.packages = with pkgs; [
    lefthook
    (writeScriptBin "git-squash" (builtins.readFile (gitSquash + "/git-squash")))
  ];

  home.file."git_ignore_global" = {
    source = ./resources/git/gitignore_global;
    target = "${config.xdg.configHome}/git/ignore";
  };

  home.file."git_template_hooks" = {
    source = ./resources/git/hooks;
    target = "${config.xdg.configHome}/git/template/hooks";
  };

  home.file."git_altinity" = {
    text = ''
      [user]
          email = hgoncalves@altinity.com
    '';
    target = "${config.xdg.configHome}/git/profiles/altinity";
  };

  programs.gh = {
    enable = true;
    extensions = with pkgs; [ gh-dash ];
    gitCredentialHelper = {
      enable = true;
      hosts = [
        "https://github.com"
        "https://gist.github.com"
      ];
    };
    settings = {
      git_protocol = "ssh";
    };
  };

  programs.gh-dash = {
    enable = true;
    settings = {
      prSections = [
        {
          title = "My Pull Requests";
          filters = "is:open author:@me";
        }
        {
          title = "Needs Review";
          filters = "is:open review-requested:@me";
        }
      ];
      issueSections = [
        {
          title = "Created";
          filters = "is:open author:@me";
        }
        {
          title = "Assigned";
          filters = "is:open assignee:@me";
        }
      ];
    };
  };

  programs.git = {
    enable = true;
    package = pkgs.gitAndTools.gitFull;

    userEmail = "kamus@hadenes.io";
    userName = "Henrique Goncalves";

    delta = {
      enable = true;
      package = pkgs.delta;
      options = {
        features = "catppuccin-macchiato";
      };
    };

    lfs = {
      enable = true;
    };

    signing = {
      key = config.age.secrets."id_ed25519.pub.age".path;
      gpgPath =
        if pkgs.stdenv.isDarwin then
          "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
        else
          "/opt/1Password/op-ssh-sign";
      signByDefault = true;
    };

    extraConfig = {
      core = {
        fsmonitor = true;
        excludesFile = "${config.xdg.configHome}/git/ignore";
      };

      github = {
        user = "kamushadenes";
      };

      init = {
        defaultBranch = "main";
        templatedir = "${config.xdg.configHome}/git/template";
      };

      merge = {
        conflictstyle = "zdiff3";
      };

      rebase = {
        autosquash = true;
        autostash = true;
        updaterefs = true;
      };

      gpg = {
        format = "ssh";
      };

      rerere = {
        enabled = true;
      };

      diff = {
        algorithm = "histogram";
      };

      push = {
        autoSetupRemote = true;
        followtags = true;
      };

      pull = {
        twohead = "ort";
      };

      includeIf = {
        "gitdir:~/Dropbox/Projects/Altinity/" = {
          path = "${config.xdg.configHome}/git/profiles/altinity";
        };
        "gitdir:/Volumes/DROPBOX/Projects/Altinity/" = {
          path = "${config.xdg.configHome}/git/profiles/altinity";
        };
      };

      include = {
        path = catppuccinDelta + "/catppuccin.gitconfig";
      };

      transfer = {
        fsckObjects = true;
      };

      fetch = {
        fsckObjects = true;
        prune = true;
        prunetags = true;
      };

      log = {
        date = "iso";
      };

      receive = {
        fsckObjects = true;
      };

      branch = {
        sort = "-committerdate";
      };

      url = {
        "git@github.com:" = {
          insteadOf = "https://github.com/";
        };
      };
    };
  };

  programs.git-cliff = {
    enable = true;
    settings = {
      changelog = {
        header = "Changelog";
        trim = true;
        footer = "";
        body = ''
          {% for group, commits in commits | group_by(attribute="group") %}
              ### {{ group | upper_first }}
              {% for commit in commits %}
                  - {{ commit.message | upper_first }}
              {% endfor %}
          {% endfor %}
        '';
      };
      git = {
        conventional_commits = true;
        filter_unconventional = true;
        tag_pattern = "v[0-9].*";
        link_parsers = [
          {
            pattern = "RFC(\\d+)";
            text = "ietf-rfc$1";
            href = "https://datatracker.ietf.org/doc/html/rfc$1";
          }
        ];
        commit_parsers = [
          {
            message = "^feat";
            group = "Features";
          }
          {
            message = "^fix";
            group = "Bug Fixes";
          }
          {
            message = "^doc";
            group = "Documentation";
          }
          {
            message = "^perf";
            group = "Performance";
          }
          {
            message = "^refactor";
            group = "Refactor";
          }
          {
            message = "^style";
            group = "Styling";
          }
          {
            message = "^test";
            group = "Testing";
          }
        ];
      };
    };
  };
}
