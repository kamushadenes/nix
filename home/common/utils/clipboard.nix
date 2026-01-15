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
    # If we're in an SSH session and the port is available, use it
    if [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ]; then
      # Check if the forwarded port is available
      if ${pkgs.netcat}/bin/nc -z localhost ${toString pbcopyPort} 2>/dev/null; then
        exec ${pkgs.netcat}/bin/nc -q1 localhost ${toString pbcopyPort}
      fi
    fi

    # Fall back to native clipboard
    if command -v /usr/bin/pbcopy >/dev/null 2>&1; then
      exec /usr/bin/pbcopy "$@"
    elif command -v xclip >/dev/null 2>&1; then
      exec xclip -selection clipboard "$@"
    elif command -v xsel >/dev/null 2>&1; then
      exec xsel --clipboard --input "$@"
    elif command -v wl-copy >/dev/null 2>&1; then
      exec wl-copy "$@"
    else
      echo "No clipboard tool available" >&2
      cat > /dev/null
    fi
  '';

  # pbpaste wrapper script - works on local and remote
  pbpasteScript = pkgs.writeShellScriptBin "pbpaste" ''
    # If we're in an SSH session and the port is available, use it
    if [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ]; then
      # Check if the forwarded port is available
      if ${pkgs.netcat}/bin/nc -z localhost ${toString pbpastePort} 2>/dev/null; then
        exec ${pkgs.netcat}/bin/nc -d localhost ${toString pbpastePort}
      fi
    fi

    # Fall back to native clipboard
    if command -v /usr/bin/pbpaste >/dev/null 2>&1; then
      exec /usr/bin/pbpaste "$@"
    elif command -v xclip >/dev/null 2>&1; then
      exec xclip -selection clipboard -o "$@"
    elif command -v xsel >/dev/null 2>&1; then
      exec xsel --clipboard --output "$@"
    elif command -v wl-paste >/dev/null 2>&1; then
      exec wl-paste "$@"
    else
      echo "No clipboard tool available" >&2
    fi
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
