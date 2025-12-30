RG_PREFIX='rga --files-with-matches'
file=$(
  FZF_DEFAULT_COMMAND="$RG_PREFIX '$1'" \
  fzf --sort \
      --preview="test ! -z {} && rga --pretty --context 5 {q} {}" \
      --phony -q "$1" \
      --bind "change:reload:$RG_PREFIX {q}" \
      --preview-window='50%:wrap'
) && echo "opening $file" && open "$file"
