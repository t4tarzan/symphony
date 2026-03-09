# Commit Skill

Create clean, conventional commits that are easy to review and bisect.

## Rules

1. **Format:** Use [Conventional Commits](https://www.conventionalcommits.org/) format:
   ```
   type(scope): short description
   
   Optional longer body explaining WHY (not what).
   
   Refs: LINEAR-123
   ```

2. **Subject line:**
   - Keep under 72 characters
   - Use imperative mood: "add feature" not "adds feature" or "added feature"
   - No trailing period
   - Lowercase after the colon

3. **Types:**
   - `feat` — new feature
   - `fix` — bug fix
   - `refactor` — code change that neither fixes a bug nor adds a feature
   - `test` — adding or updating tests
   - `docs` — documentation only
   - `chore` — build process, dependency updates, tooling
   - `perf` — performance improvement
   - `ci` — CI/CD configuration changes

4. **Scope:** Use the affected module/component, e.g. `feat(auth):`, `fix(api):`.

5. **Reference the Linear issue:** Always include `Refs: ISSUE-ID` in the commit body.

6. **Atomic commits:** Each commit should represent one logical change. If you've made multiple unrelated changes, split them.

7. **Do not commit:**
   - Secrets, API keys, or tokens
   - Debug code or `console.log`/`IO.inspect` left over from development
   - Merge commits (rebase instead)
   - Temporary proof edits used for local validation

## Example

```
feat(auth): add OAuth2 token refresh on 401 responses

Previously the client would surface a 401 error to the user. Now it
automatically attempts a token refresh and retries the original request
once. If refresh fails, it redirects to the login page.

Refs: ENG-42
```
