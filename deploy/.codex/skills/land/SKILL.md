# Land Skill

Merge an approved PR safely. This skill runs when a Linear issue transitions to `Merging` state.

## Rules

1. **Never call `gh pr merge` directly.** Follow this land loop instead.

2. **Pre-land checklist:**
   - [ ] PR is in `Merging` state (approved by human reviewer)
   - [ ] All PR checks are green
   - [ ] Branch is up to date with `origin/main` (run `pull` skill)
   - [ ] No outstanding review comments

3. **Land loop:**
   ```bash
   # Step 1: Ensure branch is current
   git fetch origin
   git merge origin/main --no-edit
   
   # Step 2: Run final validation
   # (Run whatever test/lint/build commands apply to this repo)
   
   # Step 3: Push any merge commits
   git push
   
   # Step 4: Merge via GitHub CLI (squash merge preferred for clean history)
   gh pr merge <PR_NUMBER> --squash --auto --delete-branch
   ```

4. **After merge:**
   - Confirm PR status shows `Merged` on GitHub
   - Move the Linear issue to `Done`
   - Record completion in the workpad

5. **If `--auto` merge is enabled** on the repo, `gh pr merge --auto` will wait for checks to pass automatically.

6. **If the merge fails** (conflicts after auto-merge attempt):
   - Resolve conflicts locally
   - Push the resolution
   - Re-attempt the merge

## Squash vs merge commit

- Default: `--squash` (clean linear history, single commit per PR)
- If the repo policy requires merge commits: `--merge`
- If the repo requires rebase merges: `--rebase`

Check the repo's branch protection settings if unsure.
