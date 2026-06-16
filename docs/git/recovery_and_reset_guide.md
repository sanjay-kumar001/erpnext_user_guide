# Git Commit Recovery & Reset Guide

## Overview

This guide documents common Git scenarios involving:

* Undoing the last commit
* Deleting the last commit locally and remotely
* Recovering from `git reset`
* Understanding `git reflog`
* Recovering lost commits
* Working with local and remote branch divergence

---

# 1. Undo vs Delete a Commit

There are two fundamentally different operations:

| Action                     | Command      | History Rewritten? |
| -------------------------- | ------------ | ------------------ |
| Undo a commit safely       | `git revert` | No                 |
| Delete a commit completely | `git reset`  | Yes                |

---

## Safe Undo (Recommended for Shared Branches)

Create a new commit that reverses the previous commit:

```bash
git revert HEAD
git push origin <branch-name>
```

### Result

Before:

```text
A <- B <- C (HEAD)
```

After:

```text
A <- B <- C <- D (HEAD)
```

Where:

* `C` = original commit
* `D` = revert commit

History remains intact.

---

# 2. Delete the Last Commit

## Keep Changes Staged

```bash
git reset --soft HEAD~1
```

Result:

* Commit removed
* Changes remain staged

---

## Keep Changes Unstaged

```bash
git reset --mixed HEAD~1
```

Result:

* Commit removed
* Changes remain in working directory
* Changes become unstaged

---

## Delete Commit and Changes

```bash
git reset --hard HEAD~1
```

Result:

* Commit removed
* Changes deleted from working tree

⚠️ Dangerous operation.

---

# 3. Undo a `git reset --mixed HEAD~1`

Example:

```bash
git reset --mixed HEAD~1
```

Recover using:

```bash
git reflog
```

Example output:

```text
abc123 HEAD@{0}: reset: moving to HEAD~1
def456 HEAD@{1}: commit: Fix bug
```

Restore:

```bash
git reset --mixed HEAD@{1}
```

Or:

```bash
git reset --hard HEAD@{1}
```

---

# 4. Understanding Reflog

`git reflog` records where HEAD has pointed.

Example:

```text
72d18b0 HEAD@{0}: reset: moving to HEAD~1
74c7603 HEAD@{1}: reset: moving to 74c7603
72d18b0 HEAD@{2}: reset: moving to HEAD~1
74c7603 HEAD@{3}: reset: moving to HEAD~1
afba0d8 HEAD@{4}: commit: change logo
74c7603 HEAD@{5}: commit: feat: add Azure OpenAI as AI provider
72d18b0 HEAD@{6}: commit: feat: add prescriptive analytics tools
```

Important:

* Reflog is your safety net.
* Most "lost" commits can be recovered from reflog.

---

# 5. Recovery Scenario From This Conversation

## Commands Executed

```bash
git reset --soft HEAD~1
git reset --hard HEAD~1
```

---

## Reflog Analysis

Target commit:

```text
74c7603
```

To move HEAD back:

```bash
git reset --hard 74c7603
```

Or preserve changes:

```bash
git reset --mixed 74c7603
```

Or keep them staged:

```bash
git reset --soft 74c7603
```

---

# 6. Branch Graph Analysis

Observed output:

```bash
git log --oneline --graph --decorate --all
```

Output:

```text
* afba0d8 (origin/main) change logo
* 74c7603 (HEAD -> main) feat: add Azure OpenAI as AI provider
* 72d18b0 feat: add prescriptive analytics tools
* b2e4f0d fix chat input area
* 0d28e54 cleanup
```

Interpretation:

```text
0d28e54 cleanup
└── b2e4f0d fix chat input area
    └── 72d18b0 feat: add prescriptive analytics tools
        └── 74c7603 feat: add Azure OpenAI as AI provider
            └── afba0d8 change logo
```

---

# 7. Local vs Remote State

Current state:

```text
HEAD (local main)    -> 74c7603
origin/main          -> afba0d8
```

Meaning:

* Local branch is behind remote by one commit.
* Remote contains:

```text
afba0d8 change logo
```

---

## Verify Difference

```bash
git log --oneline HEAD..origin/main
```

Expected:

```text
afba0d8 change logo
```

---

# 8. Inspect a Commit

View commit:

```bash
git show afba0d8
```

Output showed:

```text
change logo
```

with modifications to:

```text
ai_chatbot/desktop_icon/chatbot.json
```

---

# 9. Common Next Actions

## Option A — Stay at 74c7603

No action required.

Verify:

```bash
git rev-parse --short HEAD
```

Expected:

```text
74c7603
```

---

## Option B — Bring Remote Commit Back

```bash
git pull origin main
```

or

```bash
git merge origin/main
```

Result:

```text
74c7603
└── afba0d8
```

---

## Option C — Remove Remote Commit

If you want remote to match local:

```bash
git push --force-with-lease origin main
```

⚠️ Rewrites remote history.

Use only if removing `afba0d8` is intentional.

---

# 10. Recommended Safety Practices

## Create Backup Branch Before Reset

```bash
git branch backup-before-reset
```

---

## Inspect Before Force Push

```bash
git diff HEAD..origin/main
```

```bash
git show <commit>
```

```bash
git log --graph --decorate --all
```

---

## Prefer Force-With-Lease

Good:

```bash
git push --force-with-lease origin main
```

Avoid:

```bash
git push --force origin main
```

`--force-with-lease` prevents accidentally overwriting teammates' work.

---

# 11. Recovery Cheat Sheet

## Undo Last Commit Safely

```bash
git revert HEAD
```

---

## Remove Last Commit But Keep Changes

```bash
git reset --soft HEAD~1
```

---

## Remove Last Commit And Unstage Changes

```bash
git reset --mixed HEAD~1
```

---

## Remove Last Commit And Delete Changes

```bash
git reset --hard HEAD~1
```

---

## Recover Lost Commit

```bash
git reflog
git reset --hard <commit-hash>
```

---

## Move HEAD To Specific Commit

```bash
git reset --hard <commit-hash>
```

Example:

```bash
git reset --hard 74c7603
```

---

## Check Local vs Remote Difference

```bash
git log --oneline HEAD..origin/main
```

---

## Visualize Entire History

```bash
git log --oneline --graph --decorate --all
```

---

# Final State Reached During This Session

```text
Local main  -> 74c7603
Remote main -> afba0d8
```

The only remaining decision is whether the remote commit:

```text
afba0d8 change logo
```

should be:

* Kept (merge/pull it locally), or
* Removed (force-push local state to remote).
