# Fish-only: uses fish-specific array syntax ($argv[1])
if test -z "$argv[1]"
    echo "Usage: add_go_build_tags '<BUILD_CONSTRAINT_STRING>'"
    echo "Example: add_go_build_tags 'customtag || (another && !ignorethis)'"
    echo "Error: BUILD_CONSTRAINT_STRING argument is missing."
    return 1
end

set constraint_string "$argv[1]"
set new_build_directive "//go:build $constraint_string"

for go_file in (find . -type f -name "*.go")
    set first_line ""
    if test -s "$go_file"
        set first_line (head -n 1 "$go_file")
    end

    if test "$first_line" = "$new_build_directive"
        echo "Skipping (already has directive): $go_file"
        continue
    end

    echo "Processing: $go_file"

    set temp_file (mktemp --tmpdir go_build_update.XXXXXX)
    if test $status -ne 0 -o ! -f "$temp_file"
        echo "Error: Could not create temporary file for $go_file."
        if test -f "$temp_file"; rm -f "$temp_file"; end
        continue
    end

    echo "$new_build_directive" > "$temp_file"
    echo "" >> "$temp_file"
    cat "$go_file" >> "$temp_file"

    if test $status -ne 0
        echo "Error: Failed to prepare new content for $go_file."
        rm -f "$temp_file"
        continue
    end

    if mv "$temp_file" "$go_file"
        # Successfully moved
    else
        echo "Error: Could not move temporary file to replace $go_file."
        rm -f "$temp_file"
    end
end

echo "Finished processing Go files."
