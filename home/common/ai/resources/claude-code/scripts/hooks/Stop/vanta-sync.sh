#!/bin/bash
# Vanta sync reminder on Stop
# Simple reminder to check Vanta compliance status periodically

cd "${CLAUDE_PROJECT_DIR:-.}"

# Only remind in projects that might have Vanta integration
# Check for common indicators of a project with compliance requirements
if [[ -f "terraform.tf" ]] || [[ -f "main.tf" ]] || [[ -d "terraform" ]] || [[ -d "infrastructure" ]]; then
	# Reminder to check compliance (infrequent, only when relevant)
	if [[ -n "${VANTA_REMINDER:-}" ]]; then
		echo "Tip: Run /vanta-sync to check compliance status for this infrastructure project."
	fi
fi

exit 0
