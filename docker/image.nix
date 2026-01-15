# Docker image using pkgs.dockerTools.buildLayeredImage
# More reliable than nixos-generators docker format
{
  pkgs,
  pkgs-unstable,
  lib,
  system,
  claudebox ? null,
}:
let
  # User configuration
  user = "kamushadenes";
  uid = "1000";
  gid = "1000";
  home = "/home/${user}";

  # Entrypoint script
  entrypoint = pkgs.writeShellScriptBin "entrypoint" (builtins.readFile ./entrypoint.sh);

  # Core packages for the container
  corePackages = with pkgs; [
    # Basic system utilities
    bashInteractive
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    which
    procps
    less
    file
    gettext
    readline
    xz

    # Network utilities
    curl
    wget
    openssh
    cacert
    git

    # Shells
    fish
    zsh

    # Editors
    pkgs-unstable.neovim
    vim

    # Development tools
    go
    nodejs
    python3
    gnumake
    gcc

    # Container utilities
    tini

    # Infrastructure
    docker-client
    kubectl
    jq
    yq-go
    ripgrep
    fd
    fzf
    eza
    bat
    delta
    lazygit
    tmux
    starship
  ]
  # Add claude-code if available
  ++ lib.optionals (pkgs-unstable ? claude-code) [ pkgs-unstable.claude-code ]
  # Add claudebox if provided
  ++ lib.optionals (claudebox != null) [ claudebox ];

  # Create /etc files
  etcFiles = pkgs.runCommand "etc-files" { } ''
    mkdir -p $out/etc

    # passwd
    cat > $out/etc/passwd << 'EOF'
    root:x:0:0:root:/root:/bin/bash
    ${user}:x:${uid}:${gid}:${user}:${home}:${pkgs.fish}/bin/fish
    nobody:x:65534:65534:Nobody:/:/sbin/nologin
    EOF

    # group
    cat > $out/etc/group << 'EOF'
    root:x:0:
    ${user}:x:${gid}:
    wheel:x:10:${user}
    nogroup:x:65534:
    EOF

    # shadow (empty passwords)
    cat > $out/etc/shadow << 'EOF'
    root:!:1::::::
    ${user}:!:1::::::
    EOF

    # nsswitch.conf
    cat > $out/etc/nsswitch.conf << 'EOF'
    passwd:    files
    group:     files
    shadow:    files
    hosts:     files dns
    EOF

    # shells
    cat > $out/etc/shells << EOF
    /bin/bash
    ${pkgs.bashInteractive}/bin/bash
    ${pkgs.fish}/bin/fish
    ${pkgs.zsh}/bin/zsh
    EOF
  '';

  # Fish configuration
  fishConfig = pkgs.writeTextDir "home/${user}/.config/fish/config.fish" ''
    # Basic fish configuration for container
    set -gx EDITOR nvim
    set -gx VISUAL nvim
    set -gx PAGER less

    # Starship prompt
    if command -q starship
      starship init fish | source
    end

    # PATH additions
    fish_add_path $HOME/.local/bin
    fish_add_path $HOME/go/bin
    fish_add_path $HOME/.cargo/bin
  '';

  # Git configuration
  gitConfig = pkgs.writeTextDir "home/${user}/.gitconfig" ''
    [user]
      name = Henrique Goncalves
      email = henrique@kamushadenes.com
    [init]
      defaultBranch = main
    [core]
      editor = nvim
      pager = delta
    [interactive]
      diffFilter = delta --color-only
    [delta]
      navigate = true
      side-by-side = true
    [merge]
      conflictstyle = diff3
    [diff]
      colorMoved = default
    [pull]
      rebase = true
  '';

in
pkgs.dockerTools.buildLayeredImage {
  name = "nixos-claude-sandbox";
  tag = "latest";

  maxLayers = 120;

  contents = [
    etcFiles
    fishConfig
    gitConfig
    entrypoint
    pkgs.dockerTools.caCertificates
    pkgs.dockerTools.usrBinEnv
    pkgs.dockerTools.binSh
  ] ++ corePackages;

  extraCommands = ''
    # Create directory structure
    mkdir -p home/${user}/.config
    mkdir -p home/${user}/.local/bin
    mkdir -p home/${user}/.local/share
    mkdir -p home/${user}/.local/state
    mkdir -p home/${user}/.cache
    mkdir -p home/${user}/.ssh
    mkdir -p home/${user}/.age
    mkdir -p home/${user}/.claude
    mkdir -p tmp
    mkdir -p var/tmp
    mkdir -p run/user/${uid}
    mkdir -p workspace

    # Set permissions
    chmod 1777 tmp var/tmp
    chmod 700 run/user/${uid}
    chmod 700 home/${user}/.ssh
    chmod 700 home/${user}/.age

    # Create symlinks for shells
    mkdir -p bin usr/bin
    ln -sf ${pkgs.bashInteractive}/bin/bash bin/bash
    ln -sf ${pkgs.bashInteractive}/bin/bash bin/sh
  '';

  config = {
    User = user;
    WorkingDir = "/workspace";
    Entrypoint = [ "${pkgs.tini}/bin/tini" "--" "${entrypoint}/bin/entrypoint" ];
    Cmd = [ ];

    Env = [
      "HOME=${home}"
      "USER=${user}"
      "SHELL=${pkgs.fish}/bin/fish"
      "TERM=xterm-256color"
      "LANG=en_US.UTF-8"
      "LC_ALL=en_US.UTF-8"
      "EDITOR=nvim"
      "VISUAL=nvim"
      "PAGER=less"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "PATH=${lib.makeBinPath corePackages}:/home/${user}/.local/bin:/home/${user}/go/bin"
      "XDG_CONFIG_HOME=${home}/.config"
      "XDG_DATA_HOME=${home}/.local/share"
      "XDG_STATE_HOME=${home}/.local/state"
      "XDG_CACHE_HOME=${home}/.cache"
      "XDG_RUNTIME_DIR=/run/user/${uid}"
    ];

    Labels = {
      "org.opencontainers.image.title" = "NixOS Claude Sandbox";
      "org.opencontainers.image.description" = "NixOS-based development environment with Claude Code";
    };
  };
}
