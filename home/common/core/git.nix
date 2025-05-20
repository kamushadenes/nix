{
  lib,
  pkgs,
  config,
  packages,
  helpers,
  themes,
  ...
}:
{
  home.packages = with pkgs; [
    lefthook
    onefetch
    gitnr
    (writeScriptBin "git-info" "onefetch")
    (writeScriptBin "git-squash" (builtins.readFile (packages.gitSquash + "/git-squash")))
    (writeScriptBin "git-ignore" "gitnr")
  ];

  xdg.configFile."git/ignore" = {
    source = ./resources/git/gitignore_global;
  };

  xdg.configFile."git/template/hooks" = {
    source = ./resources/git/hooks;
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

    userEmail = (helpers.mkEmail "kamus" "hadenes.io");
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
      signer =
        if pkgs.stdenv.isDarwin then
          "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
        else
          (lib.getExe' pkgs._1password-gui "op-ssh-sign");
      signByDefault = true;
    };

    includes =
      [ { path = themes.deltaCatppuccin + "/catppuccin.gitconfig"; } ]
      ++ (helpers.mkConditionalGithubIncludes "Altinity" {
        user = {
          email = (helpers.mkEmail "hgoncalves" "altinity.com");
        };
      })
      ++ (helpers.mkConditionalGithubIncludes "stellarentropy" {
        user = {
          email = (helpers.mkEmail "kamus" "se.team");
        };
      });

    extraConfig = {
      core = {
        fsmonitor = true;
        excludesFile = "${config.home.homeDirectory}/${config.xdg.configFile."git/ignore".target}";
        untrackedCache = "keep";
      };

      github = {
        user = "kamushadenes";
      };

      init = {
        defaultBranch = "main";
        templatedir = "${config.home.homeDirectory}/${config.xdg.configFile."git/template/hooks".target}";
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
        rebase = true;
        twohead = "ort";
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
