{
  config,
  pkgs,
  pkgs-unstable,
  lib,
  ...
}:
{
  programs = {
    vscode = {
      enable = true;
      package = pkgs-unstable.vscode;

      profiles = {
        default = {
          enableExtensionUpdateCheck = true;
          enableUpdateCheck = false;
          userSettings = {
            "vs-kubernetes" = {
              "vs-kubernetes.minikube-show-information-expiration" = "2025-10-06T17:35:52.183Z";
            };
            "workbench.colorTheme" = "Catppuccin Macchiato";
            "workbench.iconTheme" = "catppuccin-macchiato";
            "editor.fontFamily" = "MonaspiceNe Nerd Font Mono; Monaco; 'Courier New'; monospace";
            "editor.formatOnSave" = true;
            "files.autoSave" = "onFocusChange";
            "editor.wordWrap" = "on";
            "editor.experimentalGpuAcceleration" = "on";
            "telemetry.telemetryLevel" = "off";
            "git.enableSmartCommit" = true;
            "projectManager.git.baseFolders" = [
              "/Volumes/DROPBOX/Projects"
            ];
            "go.toolsManagement.autoUpdate" = true;
            "go.useLanguageServer" = true;
            "go.addTags" = {
              "tags" = "json";
              "options" = "json=omitempty";
              "promptForTags" = false;
              "transform" = "snakecase";
            };
            "gopls" = {
              "formatting.gofumpt" = true;
              "usePlaceholders" = true;
              "ui.semanticTokens" = true;
              "staticcheck" = false;
            };
            "go.lintTool" = "golangci-lint";
            "go.lintFlags" = [
              "--fast"
              "--timeout"
              "5m"
              "--fix"
            ];
            "go.testFlags" = [
              "-cover"
              "-race"
              "-count=1"
              "-v"
              "-s"
              "-benchtime=5s"
              "-timeout=5m"
            ];
            "go.enableCodeLens" = {
              "runtest" = true;
            };
            "[go]" = {
              "editor.insertSpaces" = false;
              "editor.formatOnSave" = true;
              "editor.formatOnSaveMode" = "file";
              "editor.stickyScroll.enabled" = true;
              "editor.codeActionsOnSave" = {
                "source.organizeImports" = "always";
                "source.fixAll" = "always";
              };
            };
            "go.inlayHints.compositeLiteralFields" = true;
            "go.inlayHints.compositeLiteralTypes" = true;
            "go.inlayHints.functionTypeParameters" = true;
            "go.inlayHints.parameterNames" = true;
            "go.inlayHints.rangeVariableTypes" = true;
            "go.inlayHints.constantValues" = true;
            "go.diagnostic.vulncheck" = "Imports";
            "go.toolsEnvVars" = {
              "GOFLAGS" = "-buildvcs=false";
            };
            "git.ignoreRebaseWarning" = true;
            "git.replaceTagsWhenPull" = true;
            "makefile.configureOnOpen" = true;
            "vim.sneak" = true;
            "editor.fontSize" = 14;
            "editor.tokenColorCustomizations" = {
              "textMateRules" = [
                {
                  "scope" = [
                    "comment"
                    "comment.block"
                    "comment.block.documentation"
                    "comment.line"
                    "constant"
                    "constant.character"
                    "constant.character.escape"
                    "constant.numeric"
                    "constant.numeric.integer"
                    "constant.numeric.float"
                    "constant.numeric.hex"
                    "constant.numeric.octal"
                    "constant.other"
                    "constant.regexp"
                    "constant.rgb-value"
                    "emphasis"
                    "entity"
                    "entity.name"
                    "entity.name.class"
                    "entity.name.function"
                    "entity.name.method"
                    "entity.name.section"
                    "entity.name.selector"
                    "entity.name.tag"
                    "entity.name.type"
                    "entity.other"
                    "entity.other.attribute-name"
                    "entity.other.inherited-class"
                    "invalid"
                    "invalid.deprecated"
                    "invalid.illegal"
                    "keyword"
                    "keyword.control"
                    "keyword.operator"
                    "keyword.operator.new"
                    "keyword.operator.assignment"
                    "keyword.operator.arithmetic"
                    "keyword.operator.logical"
                    "keyword.other"
                    "markup"
                    "markup.bold"
                    "markup.changed"
                    "markup.deleted"
                    "markup.heading"
                    "markup.inline.raw"
                    "markup.inserted"
                    "markup.italic"
                    "markup.list"
                    "markup.list.numbered"
                    "markup.list.unnumbered"
                    "markup.other"
                    "markup.quote"
                    "markup.raw"
                    "markup.underline"
                    "markup.underline.link"
                    "meta"
                    "meta.block"
                    "meta.cast"
                    "meta.class"
                    "meta.function"
                    "meta.function-call"
                    "meta.preprocessor"
                    "meta.return-type"
                    "meta.selector"
                    "meta.tag"
                    "meta.type.annotation"
                    "meta.type"
                    "punctuation.definition.string.begin"
                    "punctuation.definition.string.end"
                    "punctuation.separator"
                    "punctuation.separator.continuation"
                    "punctuation.terminator"
                    "storage"
                    "storage.modifier"
                    "storage.type"
                    "string"
                    "string.interpolated"
                    "string.other"
                    "string.quoted"
                    "string.quoted.double"
                    "string.quoted.other"
                    "string.quoted.single"
                    "string.quoted.triple"
                    "string.regexp"
                    "string.unquoted"
                    "strong"
                    "support"
                    "support.class"
                    "support.constant"
                    "support.function"
                    "support.other"
                    "support.type"
                    "support.type.property-name"
                    "support.variable"
                    "variable"
                    "variable.language"
                    "variable.name"
                    "variable.other"
                    "variable.other.readwrite"
                    "variable.parameter"
                    "storage.type.ts"
                    "keyword.control.flow.ts"
                  ];
                  "settings" = {
                    "fontStyle" = "";
                  };
                }
              ];
              "[*Light*]" = {
                "textMateRules" = [
                  {
                    "scope" = "ref.matchtext";
                    "settings" = {
                      "foreground" = "#000";
                    };
                  }
                ];
              };
              "[*Dark*]" = {
                "textMateRules" = [
                  {
                    "scope" = "ref.matchtext";
                    "settings" = {
                      "foreground" = "#fff";
                    };
                  }
                ];
              };
            };
            "cline.enableCheckpoints" = false;
            "cline.disableBrowserTool" = true;
            "gitlens.ai.model" = "vscode";
            "gitlens.ai.vscode.model" = "copilot:claude-3.7-sonnet";
            "cline.vsCodeLmModelSelector" = { };
            "roo-cline.allowedCommands" = [
              "npm test"
              "npm install"
              "tsc"
              "git log"
              "git diff"
              "git show"
              "go test"
              "cd"
              "pwd"
              "ls"
              "*"
            ];
            "git.autofetch" = true;
            "[json]" = {
              "editor.defaultFormatter" = "biomejs.biome";
            };
          };
        };
      };
    };
  };
}
