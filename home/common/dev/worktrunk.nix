# Worktrunk - Git worktree management CLI
# https://worktrunk.dev/
#
# Provides simplified worktree management for AI agent workflows.
# Works alongside the `c` command which adds account detection.
{
  config,
  packages,
  ...
}:
{
  home.packages = [ packages.worktrunk ];

  # Worktrunk configuration
  # See: https://worktrunk.dev/config/
  xdg.configFile."worktrunk/config.toml".text = ''
    # Worktree path template (relative to repo parent)
    # Creates: ~/code/worktrees/myrepo/feature-branch/
    # Variables: {{ repo }}, {{ branch }}, {{ branch | sanitize }}
    worktree-path = "../worktrees/{{ repo }}/{{ branch | sanitize }}"
  '';
}
