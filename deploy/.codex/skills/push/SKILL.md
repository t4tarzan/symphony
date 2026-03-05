# Push Skill

Push local commits to the remote repository safely and reliably.

## Rules

1. **Always push to `origin`.**

2. **Set upstream on first push** for a new branch:
   ```bash
   git push -u origin HEAD
   ```
   This sets the upstream tracking reference so subsequent `git push` / `git pull` commands work without arguments.

3. **Subsequent pushes** on an established branch:
   ```bash
   git push
   ```

4. **Before pushing:**
   - Ensure your branch is up to date with `origin/main` (run `pull` skill first)
   - Ensure tests/validation pass
   - Ensure no temporary proof edits remain uncommitted

5. **Force push rules:**
   - `--force-with-lease` is acceptable when rebasing a feature branch (NOT `main` or `origin/main`)
   - Never force-push to `main`, `master`, or any protected branch
   - If force push is needed: `git push --force-with-lease`

6. **After pushing:**
   - Verify the push succeeded (no error output)
   - If a PR exists, confirm it reflects the latest commits
   - Record the push result (short SHA, branch) in the workpad Notes

## Common scenarios

```bash
# New branch, first push
git push -u origin HEAD

# Existing branch, update
git push

# After a rebase on feature branch
git push --force-with-lease

# Verify remote state
git log origin/$(git branch --show-current) --oneline -5
```
