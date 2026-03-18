# Bash Scripting Rules

## Shebang

- Always use `#!/usr/bin/env bash` instead of `#!/bin/bash`
- This ensures portability across NixOS and other systems where bash may not be at `/bin/bash`
