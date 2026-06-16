# Git Administration Commands Reference

## Overview

This document contains a curated collection of advanced Git administration, repository maintenance, synchronization, cleanup, history inspection, and commit message management commands commonly used by senior Git administrators and DevOps engineers.

---

# Repository Synchronization & History Management

## 1. Track All Branches from Upstream Remote

```bash
git remote set-branches upstream '*'
```

### Description
Configures the `upstream` remote to track all available branches instead of only selected branches.

### Use Case
Useful when working with large projects such as ERPNext or Frappe Framework where multiple release branches exist (`version-14`, `version-15`, `version-16`, etc.).

### Result
Git will fetch and recognize all branches available on the upstream repository.

---

## 2. Convert Shallow Clone into Full Repository

```bash
git fetch --all --unshallow --quiet
```

### Description
Fetches complete repository history from all remotes and removes shallow clone limitations.

### Parameters

| Option | Meaning |
|---|---|
| `--all` | Fetch from all remotes |
| `--unshallow` | Convert shallow clone into full clone |
| `--quiet` | Suppress verbose output |

### Use Case
Required when:
- Full commit history is needed
- Running advanced Git operations
- Performing migration or branch analysis
- Using commands like `git blame`, `git bisect`, or full changelog generation

---

# Branch Reset & Cleanup Operations

## 3. Fetch Latest Snapshot of Specific Branch

```bash
git fetch --depth=1 --no-tags upstream version-16
```

### Description
Fetches only the latest commit from the `version-16` branch of the `upstream` remote.

### Parameters

| Option | Meaning |
|---|---|
| `--depth=1` | Fetch only latest commit |
| `--no-tags` | Skip downloading tags |

### Use Case
Ideal for:
- CI/CD pipelines
- Lightweight deployments
- Fast synchronization
- Minimal bandwidth usage

---

## 4. Force Local Repository to Match Upstream Branch

```bash
git reset --hard upstream/version-16
```

### Description
Resets current local branch to exactly match `upstream/version-16`.

> ⚠️ Warning:
> This permanently removes:
> - Local commits
> - Uncommitted changes
> - Staged modifications

### Use Case
Useful when:
- Recovering broken repositories
- Re-syncing forked repositories
- Discarding unwanted local changes

---

## 5. Remove Old Reflog Entries

```bash
git reflog expire --all
```

### Description
Deletes expired reference logs (reflogs) from the repository.

### Use Case
Typically used before aggressive repository cleanup to reduce repository size.

---

## 6. Run Garbage Collection & Remove Unused Objects

```bash
git gc --prune=all
```

### Description
Optimizes repository storage and permanently removes unreachable Git objects.

### Operations Performed
- Compresses repository objects
- Cleans unnecessary files
- Removes dangling commits
- Optimizes repository performance

### Use Case
Recommended after:
- Large rebases
- History rewrites
- Hard resets
- Branch deletions

> ⚠️ Warning:
> Pruned commits may become unrecoverable.

---

# File Tracking Management

## 7. Remove File from Git Tracking Without Deleting Local File

```bash
git rm --cached <file/folder path>
```

### Description
Removes the file from Git version control while keeping the physical file on disk.

### Difference

| Command | Result |
|---|---|
| `git rm file` | Deletes file locally + from Git |
| `git rm --cached file` | Removes only from Git tracking |

### Use Case
Commonly used when:
- Adding files to `.gitignore`
- Removing generated files from repository
- Excluding secrets/configuration files
- Stopping tracking of build artifacts

---

# Git History & Log Formatting

## 8. Display Compact Colored Commit History

```bash
git log --date=short --pretty="%C(Yellow)%h %x09 %C(reset)%ad %x09 %C(Cyan)%an: %C(reset)%s"
```

### Description
Shows formatted Git commit history with:
- Short commit hash
- Commit date
- Author name
- Commit message

### Example Output

```text
a1b2c3d    2026-05-14    Sanjay Kumar: Fixed upstream sync issue
```

### Format Components

| Token | Meaning |
|---|---|
| `%h` | Short commit hash |
| `%ad` | Author date |
| `%an` | Author name |
| `%s` | Commit subject |
| `%C(...)` | Apply terminal colors |
| `%x09` | Tab spacing |

### Use Case
Helpful for:
- Release reviews
- Audit logs
- Quick history inspection
- Terminal-friendly reporting

---

## 9. Display Oldest 10 Commits in Chronological Order

```bash
git log --reverse --date=short -10 --pretty="%C(Yellow)%h %x09 %C(reset)%ad %x09 %C(Cyan)%an: %C(reset)%s"
```

### Description
Displays the first 10 commits in chronological order (oldest → newest).

### Parameters

| Option | Meaning |
|---|---|
| `--reverse` | Reverse default log order |
| `-10` | Limit output to 10 commits |

### Use Case
Useful for:
- Viewing repository origin history
- Auditing initial development stages
- Understanding project evolution
- Migration analysis

### Example Output
```text
b708542          2026-05-13      Sanjay Kumar: fix: serialize date/datetime in chat api to prevent JSON errors
0d28e54          2026-05-14      Sanjay Kumar: cleanup
b2e4f0d          2026-05-18      Sanjay Kumar: fix chat input area
72d18b0          2026-06-14      Sanjay Kumar: feat: add prescriptive analytics tools
74c7603          2026-06-14      Sanjay Kumar: feat: add Azure OpenAI as AI provider

```

## 10. Display order by date

```bash
git log --oneline --decorate --graph --all --date-order
```

### Description
Displays a compact, visual commit history for all branches, showing branch/tag references and ordering commits by date while preserving commit relationships.

### Parameters
| Parameter      | Purpose                                         |
| -------------- | ----------------------------------------------- |
| `--oneline`    | One commit per line                             |
| `--decorate`   | Show branch, tag, and HEAD references           |
| `--graph`      | Draw commit tree/graph                          |
| `--all`        | Include all local and remote branches           |
| `--date-order` | Sort commits by date while maintaining ancestry |

### Use Case
Useful for:
- Check current HEAD position
- Compare local vs remote branches
- Verify results of reset, rebase, or merge
- Visualize branch history and commit relationships
- Troubleshoot missing or detached commits
- Inspect history before a force push

### Example Output

```text
* afba0d8 (origin/main) change logo
* 74c7603 (HEAD -> main) feat: add Azure OpenAI as AI provider
* 72d18b0 feat: add prescriptive analytics tools
```

---

# Commit Message Management

## 10. Remove or Edit Text from Last Commit Message

```bash
git commit --amend
```

### Description
Opens the default Git editor and allows modification of the most recent commit message.

### Example

Current commit message:

```text
Fixed login issue and temporary debug logs
```

After editing:

```text
Fixed login issue
```

## 11. Remove File From Last Commit
```bash
git rm --cached <file>        # untrack the file (keeps it on disk)
git add .gitignore            # stage any other changes (optional)
git commit --amend --no-edit  # rewrite the last commit without the file
```

---

## Direct One-Line Method

Replace the complete commit message directly:

```bash
git commit --amend -m "Fixed login issue"
```

---

## If Commit Was Already Pushed

After modifying a pushed commit, force push is required:

```bash
git push --force-with-lease
```

### Why `--force-with-lease` is Recommended

Safer than `--force` because it prevents accidentally overwriting changes pushed by other contributors.

---

## Additional Useful Variations

### Amend Commit Without Changing Message

```bash
git commit --amend --no-edit
```

### Amend Author Information

```bash
git commit --amend --author="Your Name <email@example.com>"
```

---

# Recommended Maintenance Workflow

```bash
git remote set-branches upstream '*'

git fetch --all --unshallow --quiet

git fetch --depth=1 --no-tags upstream version-16

git reset --hard upstream/version-16

git reflog expire --all

git gc --prune=all
```

## Purpose of This Workflow

This sequence is commonly used to:
- Fully synchronize a fork
- Convert shallow clones to complete repositories
- Clean repository history
- Optimize repository storage
- Force repository consistency with upstream source

---

# Important Safety Notes

> ⚠️ Always create a backup branch before destructive operations:

```bash
git branch backup-before-reset
```

> ⚠️ Commands such as:
> - `git reset --hard`
> - `git gc --prune=all`
>
> can permanently remove recoverable history.

---

# Quick Command Reference Table

| Purpose | Command |
|---|---|
| Track all upstream branches | `git remote set-branches upstream '*'` |
| Convert shallow clone to full clone | `git fetch --all --unshallow --quiet` |
| Fetch latest snapshot only | `git fetch --depth=1 --no-tags upstream version-16` |
| Force reset to upstream | `git reset --hard upstream/version-16` |
| Cleanup reflogs | `git reflog expire --all` |
| Garbage collection | `git gc --prune=all` |
| Remove file from tracking only | `git rm --cached <file>` |
| Show formatted commit history | `git log --date=short --pretty="..."` |
| Show oldest commits first | `git log --reverse -10 --pretty="..."` |
| Edit last commit message | `git commit --amend` |
| Replace commit message directly | `git commit --amend -m "message"` |
| Amend without editing message | `git commit --amend --no-edit` |
| Safer force push | `git push --force-with-lease` |

---

# Best Practices

- Prefer `--force-with-lease` over `--force`
- Create backup branches before destructive operations
- Avoid aggressive pruning on shared repositories
- Use shallow fetches for CI/CD optimization
- Regularly run garbage collection for large repositories
- Never rewrite public/shared history unless necessary

---
