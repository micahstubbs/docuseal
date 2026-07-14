# Lessons Learned

Append-only log of debugging insights and non-obvious patterns.

---

## 2026-07-13T16:45 - Purging a shared-ancestor string from git history across all branches

**Problem**: Asked to remove every occurrence of an old brand string from the public fork's git history and force-push. The naive move — rewrite the current branch and force-push it — would not have cleaned the fork, and a full rewrite risked destroying a concurrent session's work.

**Root Cause**: The offending string was introduced in a commit that was a **shared ancestor of all branches** (`master`, the feature branch, and a branch a *concurrent Claude session was actively committing to*). Cleaning the fork therefore required rewriting that ancestor and every descendant — i.e. all branches — and force-pushing all of them, which changes SHAs out from under any other clone.

**Lesson**: Before a history rewrite, run `git log --all -i -S<string>` (blob content) **and** `git log --all -i --grep=<string>` (commit messages) to find the true blast radius. If the string lives in shared ancestry, "clean the fork" means rewriting every ref, not just yours. Check `git worktree list` and remote heads for concurrent work before rewriting shared history.

**Solution**:
1. Fixed the working tree first (made the brand name configurable, with a neutral default) and committed normally — the deliverable that survives independent of the rewrite.
2. Confirmed with the user (destructive + affects another live session = a scope decision only they can make) and had them close the other session.
3. Ran `git filter-repo` on a **fresh `git clone --mirror`** (isolated object store — never on the shared worktree object store while another process writes), using both `--replace-text` (blobs) and `--replace-message` (commit messages) with longest-string-first rules.
4. Verified: the `-S` and `--grep` searches both return 0, and `git grep -i <string> <ref>` is 0 at every tip.
5. Force-pushed with `--force-with-lease=<ref>:<expected-old-sha>` pinned to the captured pre-rewrite SHAs.

**Prevention**:
- `--replace-text` only rewrites blob contents; commit messages need `--replace-message`. Use both.
- Order replacement rules longest→shortest so a two-word brand is consumed before a one-word substring (otherwise you get "NewName Word").
- **Blanket replacement catches your own tooling too.** A fork-invariants file that said `must_not_contain: <old-brand>` had its marker rewritten to the *new* brand, silently inverting the guard so it failed on the legitimate default name. After any history-wide string swap, re-run your guards/tests on the rewritten tip and fix collateral rewrites. (You cannot keep a literal "must not contain <old-brand>" guard once the goal is zero occurrences — replace it with a *positive* guard, e.g. "the name must be read via the configurable helper".)
- Guard hooks here block `rm -rf`, `git reset --hard`, and `git push --force`. Work with them: clone into a unique new dir instead of `rm`-ing; use `--force-with-lease=<ref>:<sha>` (safer and passes the guard) instead of `--force`; skip an unnecessary `reset --hard` when the working-tree content already matches the rewritten tip (only the SHA changed) — but if your branch sits on the *old* line, checkout the rewritten origin tip and re-apply outstanding work there so you don't re-push polluted ancestry.
- Any doc you write *about* the purge (a lessons file, a session summary) must not contain the purged literal either — genericize the example.
- After the push, every other clone/worktree must re-clone or `git reset --hard origin/<branch>` — flag this to the user explicitly.

---

## 2026-07-13T16:45 - Fan-out research over a large fork network, then pipeline the port

**Problem**: Needed to evaluate ~1,700 forks of a repo for portable features and then implement a selected subset, far more than one context can hold.

**Root Cause**: Reading every divergent fork inline would overflow context; doing it sequentially would be slow.

**Lesson**: Scout cheaply first (a background `gh api` compare script emitting TSV of `ahead_by`/`behind_by` per fork), then fan out one subagent per cluster of forks for the deep read, each returning a **structured catalog as data, not prose**. The parent keeps only the conclusions. For implementation, dispatch worktree-isolated subagents (one per feature cluster) so parallel edits don't collide. (Now packaged as the `ffh` skill.)

**Prevention**:
- Give each research subagent explicit `gh api` recipes and tell it its final message is data for a report — you get consistent, mergeable catalogs.
- When multiple implementation subagents target the same branch, tell each to stage only its own files; a shared-worktree race can sweep one agent's uncommitted file into another's commit (harmless but mis-attributed).
- Subagents can't run a toolchain the host lacks (a newer Ruby here); have them validate with `ruby -c`/`node --check`/YAML-parse and defer real specs to CI. Say so up front.
