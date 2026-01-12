# Resilio Sync File Cleanup

Resilio Sync creates temporary files (`.rslsc`, `.rsls`, etc.) that can corrupt git repos.

## When You See

- `fatal: bad object refs/heads/*.rsls*`
- `error: ... did not send all necessary objects`
- Any `.rsls*` files in git status

## Fix Immediately

```bash
# Delete corrupted git refs containing .rsls
git for-each-ref --format='%(refname)' | grep '\.rsls' | xargs -I {} git update-ref -d {}

# Delete any Resilio Sync temp files
find . -name "*.rsls*" -delete

# Prune and continue
git remote prune origin
```

Then retry the original operation.
