# cmux Notifications

When running inside cmux (detected by `CMUX_WORKSPACE_ID` environment variable),
notify the user on task completion or when input is needed:

```bash
# Task/session complete
cmux notify --title "Done" --body "Short summary of what was done"

# Needs user input
cmux notify --title "Waiting" --body "Need confirmation to proceed"

# Error
cmux notify --title "Error" --body "Build failed — see output"
```

Only send notifications for meaningful events. Do not notify on every step.
