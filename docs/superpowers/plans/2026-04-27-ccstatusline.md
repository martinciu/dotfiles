# ccstatusline Dotfiles Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Track `~/.config/ccstatusline/` in the dotfiles repo and deploy it via `bootstrap.sh`.

**Architecture:** Copy the live config directory into the repo, add a `link` call in `bootstrap.sh` (after the tmux block), and run bootstrap to replace the live directory with a symlink. Follows the identical pattern used for `ghostty` and `tmux`.

**Tech Stack:** bash, git, symlinks.

---

### Task 1: Copy ccstatusline config into the repo

**Files:**
- Create: `.config/ccstatusline/settings.json`

- [ ] **Step 1: Copy the live directory into the repo**

```bash
cp -r ~/.config/ccstatusline /Users/martinciu/code/dotfiles/.config/ccstatusline
```

- [ ] **Step 2: Verify the file is present**

```bash
ls /Users/martinciu/code/dotfiles/.config/ccstatusline
```

Expected output:
```
settings.json
```

- [ ] **Step 3: Commit**

```bash
cd /Users/martinciu/code/dotfiles
git add .config/ccstatusline
git commit -m "feat(ccstatusline): add config to dotfiles"
```

---

### Task 2: Wire ccstatusline into bootstrap.sh

**Files:**
- Modify: `bootstrap.sh`

- [ ] **Step 1: Add the link call after the tmux block**

In `bootstrap.sh`, after line 34 (`link ".config/tmux"    "$HOME/.config/tmux"`), add:

```bash
# --- ccstatusline
link ".config/ccstatusline" "$HOME/.config/ccstatusline"
```

The relevant section should look like:

```bash
# --- tmux
link ".config/tmux"    "$HOME/.config/tmux"

# --- ccstatusline
link ".config/ccstatusline" "$HOME/.config/ccstatusline"

# --- vim
```

- [ ] **Step 2: Verify the diff looks correct**

```bash
git diff bootstrap.sh
```

Expected: one new section with two lines (`# --- ccstatusline` comment + `link` call).

- [ ] **Step 3: Commit**

```bash
git add bootstrap.sh
git commit -m "feat(bootstrap): symlink ccstatusline config"
```

---

### Task 3: Run bootstrap to activate the symlink

- [ ] **Step 1: Run bootstrap**

```bash
bash /Users/martinciu/code/dotfiles/bootstrap.sh
```

Expected output includes a line like:

```
linked: /Users/martinciu/.config/ccstatusline -> /Users/martinciu/code/dotfiles/.config/ccstatusline
```

(If the live directory already existed as a real directory, bootstrap backs it up first: `BACKUP: ~/.config/ccstatusline -> ~/.config/ccstatusline.bak.<timestamp>`.)

- [ ] **Step 2: Verify the symlink is correct**

```bash
readlink ~/.config/ccstatusline
```

Expected:
```
/Users/martinciu/code/dotfiles/.config/ccstatusline
```

- [ ] **Step 3: Verify settings.json is readable through the symlink**

```bash
cat ~/.config/ccstatusline/settings.json | head -5
```

Expected: first few lines of the JSON config.
