---
name: Pushing to a second tracked branch with gitPush
description: What to do when gitPush reports the current branch already tracks a different remote branch and refuses to publish another name.
---

Some repos in this environment (e.g. wf-sober-ccg-journeys-dawn) are kept in
sync across two remote branches (`main` and `replit-stabilization`), where
the stabilization branch periodically merges `main` in via merge commits.

Calling `gitPush({ branch: "replit-stabilization" })` while the local `HEAD`
is still `main` (tracking `origin/main`) fails with:

```
CLI_ERROR: current branch already tracks origin/main; cannot publish replit-stabilization
```

**What worked:** gitPush pushes whatever is checked out under the requested
branch name — it does not switch branches for you. Fix:

```bash
git checkout replit-stabilization   # local branch already exists after prior syncs
git merge main --no-ff -m "Merge branch 'main' into replit-stabilization"
```

then call `gitPush({ branch: "replit-stabilization" })`. A plain `--ff-only`
merge usually fails too ("Diverging branches") because the stabilization
branch's own merge-commit history has diverged from `main`'s linear history
— `--no-ff` is the correct/expected merge shape here, matching the repo's
existing merge-commit log pattern.

Afterward, `git checkout main` to leave the working tree on the branch the
rest of the session expects.

**How to apply:** Whenever a repo asks for pushes to more than one branch,
never assume gitPush can target a branch not currently checked out — checkout
the target branch, merge from `main`, then push, one branch at a time.
