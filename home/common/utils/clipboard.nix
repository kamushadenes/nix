# Remote clipboard support via SSH port forwarding
#
# On Darwin (client machine):
#   - Launchd agents listen on ports 2224 (pbcopy) and 2225 (pbpaste)
#   - SSH config forwards these ports to remote hosts
#
# On Linux/remote:
#   - pbcopy/pbpaste scripts detect SSH session and use netcat
#   - Falls back to native clipboard tools when local
#
# Usage:
#   - SSH to remote with port forwarding (automatic via SSH config)
#   - Use pbcopy/pbpaste normally - they route through SSH tunnel
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Ports for clipboard forwarding
  pbcopyPort = 2224;
  pbpastePort = 2225;

  # pbcopy wrapper script - works on local and remote
  pbcopyScript = pkgs.writeShellScriptBin "pbcopy" ''
    # If we're in an SSH session, try the forwarded port first
    if [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ]; then
      if ${pkgs.netcat}/bin/nc -z localhost ${toString pbcopyPort} 2>/dev/null; then
        exec ${pkgs.netcat}/bin/nc -q1 localhost ${toString pbcopyPort}
      fi
      # Port not available - fall through to local tools
    fi

    # Fall back to native clipboard
    if command -v /usr/bin/pbcopy >/dev/null 2>&1; then
      exec /usr/bin/pbcopy "$@"
    elif [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy >/dev/null 2>&1; then
      exec wl-copy "$@"
    elif [ -n "$DISPLAY" ]; then
      if command -v xclip >/dev/null 2>&1; then
        exec xclip -selection clipboard "$@"
      elif command -v xsel >/dev/null 2>&1; then
        exec xsel --clipboard --input "$@"
      fi
    fi

    # No clipboard available
    if [ -n "$SSH_CONNECTION" ]; then
      echo "pbcopy: SSH port forwarding not available (reconnect to enable)" >&2
    else
      echo "pbcopy: No clipboard tool available (no DISPLAY or WAYLAND_DISPLAY)" >&2
    fi
    cat > /dev/null
    exit 1
  '';

  # pbpaste wrapper script - works on local and remote
  pbpasteScript = pkgs.writeShellScriptBin "pbpaste" ''
    # If we're in an SSH session, try the forwarded port first
    if [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ]; then
      if ${pkgs.netcat}/bin/nc -z localhost ${toString pbpastePort} 2>/dev/null; then
        exec ${pkgs.netcat}/bin/nc -d localhost ${toString pbpastePort}
      fi
      # Port not available - fall through to local tools
    fi

    # Fall back to native clipboard
    if command -v /usr/bin/pbpaste >/dev/null 2>&1; then
      exec /usr/bin/pbpaste "$@"
    elif [ -n "$WAYLAND_DISPLAY" ] && command -v wl-paste >/dev/null 2>&1; then
      exec wl-paste "$@"
    elif [ -n "$DISPLAY" ]; then
      if command -v xclip >/dev/null 2>&1; then
        exec xclip -selection clipboard -o "$@"
      elif command -v xsel >/dev/null 2>&1; then
        exec xsel --clipboard --output "$@"
      fi
    fi

    # No clipboard available
    if [ -n "$SSH_CONNECTION" ]; then
      echo "pbpaste: SSH port forwarding not available (reconnect to enable)" >&2
    else
      echo "pbpaste: No clipboard tool available (no DISPLAY or WAYLAND_DISPLAY)" >&2
    fi
    exit 1
  '';
in
{
  # Install wrapper scripts on all platforms
  # Note: netcat is used via full path in scripts, no need to add to PATH
  home.packages = [
    pbcopyScript
    pbpasteScript
  ];

  # Darwin-only: Launchd agents to expose clipboard via sockets
  launchd.agents = lib.mkIf pkgs.stdenv.isDarwin {
    pbcopy = {
      enable = true;
      config = {
        Label = "localhost.pbcopy";
        ProgramArguments = [ "/usr/bin/pbcopy" ];
        inetdCompatibility.Wait = false;
        Sockets = {
          Listeners = {
            SockServiceName = toString pbcopyPort;
            SockNodeName = "127.0.0.1";
          };
        };
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
      };
    };

    pbpaste = {
      enable = true;
      config = {
        Label = "localhost.pbpaste";
        ProgramArguments = [ "/usr/bin/pbpaste" ];
        inetdCompatibility.Wait = false;
        Sockets = {
          Listeners = {
            SockServiceName = toString pbpastePort;
            SockNodeName = "127.0.0.1";
          };
        };
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
      };
    };
  };
}
