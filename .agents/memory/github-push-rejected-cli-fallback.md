---
name: gitPush/CLI push rejected despite healthy GitHub connector
description: gitPush callback and raw `git push`/`git fetch` can fail or hang even when the GitHub connector itself is healthy; use the Git Data API via the connector's proxyFetch as a reliable fallback, then avoid `git reset --hard origin/<branch>` afterward.
---

Observed in wf-sober-ccg-journeys-dawn: the `gitPush` CodeExecution callback returned `PUSH_REJECTED` on a legitimate fast-forward push (verified via the GitHub REST API that the remote branch head matched the local commit's parent), and plain `git fetch origin <branch>` from the shell hung until timeout. This happened even though `listConnections('github')` via a plain Node script (see `github-connector-credential-outage.md`) reported the connection `status: "healthy"`.

**Why:** These are apparently three separate paths (gitPush wrapper, shell git CLI credential helper, direct connector SDK) that can fail independently of each other and of the connector's own health status. Retrying the same failing path in a loop wastes time; a different path already works.

**How to apply:**
1. If `gitPush` fails with `PUSH_REJECTED` and `git fetch` hangs/times out, don't loop either — switch to pushing via the GitHub Git Data API directly, using `@replit/connectors-sdk`'s `createProxyFetch('github')` (run as a real `.cjs` file in the project dir via ShellExec/node, not inside `"use impure"`, since `require` needs the workspace's `node_modules`).
2. Flow: GET the current remote branch parent commit (`/git/commits/:sha`) to get its tree sha → POST a blob for each changed file → POST a tree with `base_tree` = parent's tree sha + the new blob entries → POST a commit with that tree + `parents: [parent_sha]` → PATCH `/git/refs/heads/<branch>` to the new commit sha. For a second local branch (e.g. merging into a stabilization branch), create a merge commit with `tree` = the just-pushed commit's tree and `parents: [other_branch_head, just_pushed_sha]`, then PATCH that branch's ref.
3. **Critical gotcha:** after pushing this way, local git's `origin/<branch>` remote-tracking ref is still stale (the fetch that would update it is the same one that hangs). Do **not** run `git reset --hard origin/<branch>` — it resets to the stale cached ref and silently discards local commits/working-tree changes that only exist as content pushed via the API (different SHA, same content). If this happens, recover with `git reflog` to find the pre-reset commit and `git reset --hard <that-sha>`. Safer: just leave local HEAD on its own local commit (content already matches what's on GitHub) and skip trying to realign local git history/SHAs to the remote's API-created commits at all.
4. Delete any temp push scripts from the repo afterward.
