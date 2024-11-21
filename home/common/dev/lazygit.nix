{
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    bun
  ];

  age.secrets = {
    "lazycommit.age" = {
      file = ./resources/lazygit/lazycommit.age;
      path = "${config.home.homeDirectory}/.lazycommit";
    };
  };

  home.file.".lazycommit-template" = {
    source = ./resources/lazygit/lazycommit-template;
  };

  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        showIcons = true;
        nerdFontsVersion = "3";
      };
      customCommands = [
        {
          key = "C";
          command = "git cz";
          context = "files";
          loadingText = "opening commitizen commit tool";
          subprocess = true;
        }
        {
          key = "E";
          description = "Add empty commit";
          context = "commits";
          command = "git commit --allow-empty -m 'empty commit'";
          loadingText = "Committing empty commit...";
        }
        {
          key = "f";
          command = "git difftool -y {{.SelectedLocalCommit.Sha}} -- {{.SelectedCommitFile.Name}}";
          context = "commitFiles";
          description = "Compare (difftool) with local copy";
        }
        {
          key = "<c-c>";
          description = "commit as non-default author";
          command = ''git commit -m "{{index .PromptResponses 0}}" --author="{{index .PromptResponses 1}} <{{index .PromptResponses 2}}>"'';
          context = "files";
          prompts = [
            {
              type = "input";
              title = "Commit Message";
              initialValue = "";
            }
            {
              type = "input";
              title = "Author Name";
              initialValue = "";
            }
            {
              type = "input";
              title = "Email Address";
              initialValue = "";
            }
          ];
          loadingText = "commiting";
        }
        {
          key = "<c-a>";
          description = "Pick AI commit";
          command = ''echo "{{.Form.Msg}}" > .git/COMMIT_EDITMSG && nvim .git/COMMIT_EDITMSG && [ -s .git/COMMIT_EDITMSG ] && git commit -F .git/COMMIT_EDITMSG || echo "Commit message is empty, commit aborted."'';
          context = "files";
          subprocess = true;
          prompts = [
            {
              type = "menuFromCommand";
              title = "AI Commits";
              key = "Msg";
              command = "bunx @m7medvision/lazycommit@latest";
              filter = ''^(?P<number>\d+)\.\s(?P<message>.+)$'';
              valueFormat = "{{ .message }}";
              labelFormat = "{{ .number }}: {{ .message | green }}";
            }
          ];
        }
      ];
      git = {
        commit = {
          signOff = true;
        };
        paging = {
          colorArg = "always";
          # pager = "diff-so-fancy";
          pager = "delta --dark --paging=never --tabs 2";
        };
        branchLogCmd = "git log --graph --color=always --abbrev-commit --decorate --date=relative --pretty=medium --oneline {{branchName}} --";
      };
    };
  };
}
