#!/usr/bin/env bash
# Fix non-portable bash shebangs after Write/Edit
# Replaces #!/bin/bash with #!/usr/bin/env bash for NixOS compatibility

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# Extract file path from tool input
file_path=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // empty')
[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0
[[ "$file_path" != *.sh ]] && exit 0

# Check if first line is the non-portable shebang
first_line=$(head -n1 "$file_path")
if [[ "$first_line" == "#!/bin/bash" ]]; then
    sed -i.bak '1s|#!/bin/bash|#!/usr/bin/env bash|' "$file_path"
    rm -f "${file_path}.bak"
fi

exit 0
