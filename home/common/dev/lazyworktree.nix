{
  config,
  packages,
  ...
}:
{
  home.packages = [ packages.lazyworktree ];

  home.shellAliases.lwt = "lazyworktree";

  xdg.configFile."lazyworktree/config.yaml".text = ''
    # Worktree storage - matches c work command
    worktree_dir: ${config.home.homeDirectory}/.local/share/git/workspaces

    # Theme
    theme: catppuccin-mocha

    # Sort by last accessed
    sort_by_active: true

    # Use delta for diffs (matches lazygit)
    pager: delta --dark --paging=never --tabs 2

    # Custom commands
    custom_commands:
      e:
        command: nvim
        description: Open editor
        show_help: true
      g:
        command: lazygit
        description: Launch lazygit
        show_help: true
      t:
        command: tmux new-session -A -s worktree
        description: Tmux session
        show_help: true
  '';
}
