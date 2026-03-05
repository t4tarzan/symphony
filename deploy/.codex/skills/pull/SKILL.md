# Pull Skill

Keep your working branch synchronized with `origin/main` before handoff.

## Rules

1. **Run this skill before any handoff** (before submitting a PR or moving to Human Review).

2. **Standard sync flow:**
   ```bash
   git fetch origin
   git merge origin/main --no-edit
   ```
   If there are conflicts, resolve them before proceeding.

3. **After merging:**
   - Re-run your validation/tests to confirm nothing broke
   - Record the pull result in the workpad Notes:
     ```
     pull skill evidence:
     - merge source: origin/main
     - result: clean (or: conflicts resolved in <files>)
     - HEAD: <short-sha>
     ```

4. **If the branch has diverged significantly**, prefer rebase:
   ```bash
   git fetch origin
   git rebase origin/main
   ```
   Then push with `--force-with-lease`.

5. **Never merge `origin/main` into `origin/main` locally** — this skill only applies to feature branches.

## Conflict resolution guidelines

- For conflicts in generated files (lock files, build artifacts): take `origin/main` version and regenerate
- For conflicts in source files: merge carefully, preserving both sets of changes
- When in doubt, keep both sides and document the resolution in the workpad
