# Re-enable tmux-resurrect and tmux-continuum — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-enable `tmux-resurrect` + `tmux-continuum` with auto-restore in `.config/tmux/tmux.conf`, using conservative defaults (no process restoration, no scrollback capture, default 15-min save interval), and refresh `docs/tmux-cheatsheet.html` to match.

**Architecture:** Two-file edit: uncomment three plugin lines in `tmux.conf` (removing the `# disabled 2026-04-27 (raw-tmux trial):` comments) and update three regions plus footer date in the cheatsheet HTML. Plugin cloning is handled at runtime by TPM (already loaded); plugin directories happen to already exist on this machine from before the trial, so the runtime install step is a no-op locally but kept for fresh-machine reproducibility.

**Tech Stack:** tmux 3.x, TPM (Tmux Plugin Manager), shell, git. No build system.

**Branching:** Working from clean `main`, not in a worktree. Per CLAUDE.md branching policy: plain feature branch (no worktree spin-up) and land via PR.

**Spec:** `tmp/specs/2026-04-29-tmux-resurrect-continuum-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `.config/tmux/tmux.conf` | Modify lines 71-73 | Replace three `# disabled 2026-04-27 (raw-tmux trial):` comment lines with three active `set -g` lines (two `@plugin` declarations + `@continuum-restore 'on'`) |
| `docs/tmux-cheatsheet.html` | Modify in 4 spots | (1) update "TPM plugins" row at line 112, (2) replace the "currently disabled" note at line 168, (3) insert a new card listing resurrect/continuum bindings, (4) bump footer date at line 413 |

No new files. No `Brewfile` or `bootstrap.sh` changes — TPM is already cloned by bootstrap and loaded by tmux.conf; the new plugins are managed at runtime by TPM.

---

### Task 1: Confirm branch strategy and create feature branch

**Files:** none yet (git only)

**Context:** Project CLAUDE.md mandates "All changes go through a pull request. Never commit or merge directly to `main`/`master`." User-memory note allows trivial dotfiles edits direct-to-main but says "still confirm once per session." This change adds two plugins and updates a docs file — not trivial — so default is feature branch + PR. Confirm before proceeding to lock in the path.

- [ ] **Step 1: Confirm with user**

Ask: "This change touches `tmux.conf` and `docs/tmux-cheatsheet.html`. Default plan is a feature branch + PR. OK, or commit straight to `main`?"

Wait for explicit answer. If "direct to main," skip Steps 2-3 here and skip Task 9 entirely; commit on `main` instead in Task 8.

- [ ] **Step 2: Verify clean working tree**

Run:
```bash
cd ~/projects/dotfiles
git status
```

Expected: "On branch main / nothing to commit, working tree clean". If anything is dirty, stop and surface it to the user — don't carry unrelated changes.

- [ ] **Step 3: Create and switch to feature branch**

Run:
```bash
git checkout -b enable-resurrect-continuum
```

Expected: `Switched to a new branch 'enable-resurrect-continuum'`. No `worktree-` prefix because we're not in a worktree workflow.

---

### Task 2: Edit tmux.conf — replace disabled-comment block with active plugin lines

**Files:**
- Modify: `.config/tmux/tmux.conf:68-74`

- [ ] **Step 1: Apply the edit**

Replace the block:

```tmux
# ─── Plugins (TPM) ──────────────────────────
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
# disabled 2026-04-27 (raw-tmux trial): set -g @plugin 'tmux-plugins/tmux-resurrect'
# disabled 2026-04-27 (raw-tmux trial): set -g @plugin 'tmux-plugins/tmux-continuum'
# disabled 2026-04-27 (raw-tmux trial): set -g @continuum-restore 'on'
run '~/.config/tmux/plugins/tpm/tpm'
```

with:

```tmux
# ─── Plugins (TPM) ──────────────────────────
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
run '~/.config/tmux/plugins/tpm/tpm'
```

No other settings (no `@resurrect-processes`, no `@resurrect-capture-pane-contents`, no `@continuum-save-interval`) — defaults apply.

- [ ] **Step 2: Verify the file syntax-checks under tmux**

Run from any shell:
```bash
tmux -f ~/projects/dotfiles/.config/tmux/tmux.conf -L cfgcheck new-session -d \; kill-server
echo "exit: $?"
```

Expected: `exit: 0` and no error output. (We start a throwaway server `cfgcheck` with this config, then immediately kill it. tmux will print parse errors if any line is malformed.)

If errors appear, fix the conf before continuing. Common issues: stray characters from the edit, missing space after `set -g`.

---

### Task 3: Update cheatsheet — "TPM plugins" row at line 112

**Files:**
- Modify: `docs/tmux-cheatsheet.html:112`

- [ ] **Step 1: Apply the edit**

Replace:

```html
      <tr><td class="key">TPM plugins</td><td class="desc">tpm + tmux-sensible only (raw-tmux trial)</td></tr>
```

with:

```html
      <tr><td class="key">TPM plugins</td><td class="desc">tpm, tmux-sensible, tmux-resurrect, tmux-continuum</td></tr>
```

Rationale: the trial-era note is no longer accurate; the row should list the active plugin set.

---

### Task 4: Update cheatsheet — replace "disabled" note in Sessions section at line 168

**Files:**
- Modify: `docs/tmux-cheatsheet.html:168`

- [ ] **Step 1: Apply the edit**

Replace:

```html
    <p class="note">tmux-resurrect / continuum are currently disabled (raw-tmux trial — see <code>tmux.conf</code>).</p>
```

with:

```html
    <p class="note">tmux-resurrect + tmux-continuum auto-save sessions every 15 min and auto-restore on a fresh server. See the "Persistence" card below for bindings.</p>
```

Rationale: the trial is over; the note should describe the active behavior and point at the bindings card we add next.

---

### Task 5: Update cheatsheet — add a new "Persistence" card with resurrect/continuum bindings

**Files:**
- Modify: `docs/tmux-cheatsheet.html` — insert before the closing `</div>` of the Sessions grid (i.e. immediately after the "Sesh picker" card ends at line 187, before line 188's `</div>`)

**Context:** The Sessions section currently has three cards: "From inside tmux", "From the shell", "Sesh picker". We add a fourth card to the same grid so persistence sits visually next to the related session content.

- [ ] **Step 1: Locate the insertion point**

Run:
```bash
grep -n "Sesh picker" ~/projects/dotfiles/docs/tmux-cheatsheet.html
```

Expected: a line in the 170s pointing at the `<h3>Sesh picker ...</h3>` heading. The card containing it ends with `</div>` a few lines later, just before the grid closes.

Open the file and find the line that reads exactly `</div>` at line 187 (closing the Sesh picker card) — followed by `</div>` at line 188 (closing the whole `<div class="grid">`).

- [ ] **Step 2: Insert the new card between line 187's `</div>` and line 188's `</div>`**

Insert this block (note: it must go AFTER the Sesh picker card's `</div>` but BEFORE the grid's `</div>`):

```html

  <div class="card">
    <h3>Persistence <span class="pill">resurrect + continuum</span></h3>
    <table>
      <tr><td class="key"><span class="k prefix">C-a</span> <span class="k">C-s</span></td><td class="desc">save snapshot now (manual)</td></tr>
      <tr><td class="key"><span class="k prefix">C-a</span> <span class="k">C-r</span></td><td class="desc">restore latest snapshot (manual)</td></tr>
      <tr><td class="key">auto-save</td><td class="desc">every 15 min (continuum default)</td></tr>
      <tr><td class="key">auto-restore</td><td class="desc">on fresh tmux server start (<code>@continuum-restore 'on'</code>)</td></tr>
      <tr><td class="key">snapshots in</td><td class="desc"><code>~/.local/share/tmux/resurrect/</code></td></tr>
    </table>
    <p class="note">Defaults only: no <code>@resurrect-processes</code> (panes get fresh shells in <code>cwd</code>; nvim/ssh are NOT relaunched), no <code>@resurrect-capture-pane-contents</code> (scrollback is not saved). Auto-restore only fires on a brand-new server with zero sessions, so attaching to an already-running server (sesh's normal flow) is unaffected.</p>
  </div>
```

The leading blank line keeps spacing consistent with the surrounding cards.

- [ ] **Step 3: Verify the insertion**

Run:
```bash
grep -n "Persistence" ~/projects/dotfiles/docs/tmux-cheatsheet.html
```

Expected: one match showing the new `<h3>Persistence ...` line.

Also run a quick HTML well-formedness check by counting `<div class="card">` vs `</div>`:
```bash
grep -c '<div class="card">' ~/projects/dotfiles/docs/tmux-cheatsheet.html
```

Note the count and confirm it increased by exactly 1 vs git HEAD:
```bash
git show HEAD:docs/tmux-cheatsheet.html | grep -c '<div class="card">'
```

Expected: new count = old count + 1.

---

### Task 6: Update cheatsheet — refresh footer date

**Files:**
- Modify: `docs/tmux-cheatsheet.html:413`

- [ ] **Step 1: Apply the edit**

Replace:

```html
  Built from <code>~/.config/tmux/tmux.conf</code> on 2026-04-28. Refresh after meaningful config changes.
```

with:

```html
  Built from <code>~/.config/tmux/tmux.conf</code> on 2026-04-29. Refresh after meaningful config changes.
```

---

### Task 7: Render-check the cheatsheet in a browser

**Files:** none (read-only verification)

- [ ] **Step 1: Open the file in the default browser**

Run:
```bash
open ~/projects/dotfiles/docs/tmux-cheatsheet.html
```

- [ ] **Step 2: Visually inspect**

Confirm:
1. The "TPM plugins" row in the "At a glance" card no longer says "raw-tmux trial".
2. The Sessions section's middle card ("From the shell") no longer has the red/grey "currently disabled" note — it now says "auto-save sessions every 15 min...".
3. A new "Persistence" card appears in the Sessions grid, listing `C-s` / `C-r` bindings, auto-save, auto-restore, snapshots-in.
4. The footer date reads `2026-04-29`.
5. No layout breakage (the new card should fit in the grid without overflowing, matching the styling of its neighbors).

If anything looks broken (unclosed tags, garbled text, layout off), fix in the file and re-open.

---

### Task 8: Commit the change

**Files:** none (git only — staging only the two files modified above)

- [ ] **Step 1: Review the diff**

Run:
```bash
cd ~/projects/dotfiles
git diff
```

Expected diff regions:
- `.config/tmux/tmux.conf`: 3 lines removed (`# disabled 2026-04-27 ...`), 3 lines added (`set -g @plugin 'tmux-plugins/tmux-resurrect'`, `set -g @plugin 'tmux-plugins/tmux-continuum'`, `set -g @continuum-restore 'on'`).
- `docs/tmux-cheatsheet.html`: ~15-20 lines added (mostly the new card), ~3 lines modified (TPM-plugins row, disabled-note paragraph, footer date).

- [ ] **Step 2: Stage exactly the two files**

Run:
```bash
git add .config/tmux/tmux.conf docs/tmux-cheatsheet.html
```

Use explicit file paths — do NOT use `git add -A` or `git add .` (per project conventions).

- [ ] **Step 3: Commit**

Recent commit-message style in this repo: prefix-style with type and scope, e.g. `docs(claude): drop wt references...`, conventional-commits-ish. Use:

```bash
git commit -m "$(cat <<'EOF'
feat(tmux): re-enable tmux-resurrect and tmux-continuum

End the 2026-04-27 raw-tmux trial. Re-enable both plugins with the
auto-restore continuum setting; defaults only (no process restoration,
no pane-contents capture, 15-min save interval). Update the tmux
cheatsheet to reflect the active plugin set, drop the "currently
disabled" note, add a Persistence card with the relevant bindings,
and refresh the footer date.
EOF
)"
```

Expected: commit succeeds, no Claude co-author trailer.

- [ ] **Step 4: Confirm clean status post-commit**

Run:
```bash
git status
```

Expected: `nothing to commit, working tree clean`.

---

### Task 9: Push branch and open PR (skip if user chose direct-to-main in Task 1)

**Files:** none (remote git only)

- [ ] **Step 1: Push the branch**

Run:
```bash
git push -u origin enable-resurrect-continuum
```

Expected: branch is pushed, upstream is set. No `worktree-` prefix to strip (we never had one).

- [ ] **Step 2: Open PR**

Run:
```bash
gh pr create --title "Re-enable tmux-resurrect and tmux-continuum" --body "$(cat <<'EOF'
## Summary
- Re-enable `tmux-plugins/tmux-resurrect` and `tmux-plugins/tmux-continuum` in `.config/tmux/tmux.conf` with `@continuum-restore 'on'`. Conservative defaults only — no process restoration, no pane-contents capture, default 15-min save interval.
- Update `docs/tmux-cheatsheet.html`: refresh the "TPM plugins" row, drop the "currently disabled" note in the Sessions section, add a new "Persistence" card with manual save/restore bindings and behavior summary, bump the footer date.

## Why
The 2026-04-27 raw-tmux trial is concluding. Auto-save + auto-restore returns; sesh-driven session creation continues to work because auto-restore only fires on a fresh server with zero existing sessions.

## Test plan
- [ ] `tmux -f ~/projects/dotfiles/.config/tmux/tmux.conf -L cfgcheck new-session -d \; kill-server` exits 0 (config parses).
- [ ] After bootstrap (or `<prefix> r` + `<prefix> I` from inside tmux), `ls ~/.config/tmux/plugins/` lists `tmux-resurrect` and `tmux-continuum`.
- [ ] `<prefix> Ctrl-s` flashes a save status; a snapshot file appears under `~/.local/share/tmux/resurrect/`.
- [ ] `open docs/tmux-cheatsheet.html` shows the new Persistence card, the corrected TPM-plugins row, and footer date `2026-04-29`.
- [ ] (Optional, disruptive) `tmux kill-server` and start a fresh tmux — prior session shape returns automatically.
EOF
)"
```

Note: no ticket number in the title because dotfiles is a personal repo with no Jira project. (The "ticket number in PR title" rule from `~/.claude/CLAUDE.local.md` applies to work-project PRs.)

Expected: `gh pr create` returns the PR URL. Print it for the user.

- [ ] **Step 3: Surface the PR URL to the user**

End the session by pasting the PR URL so the user can open it for review.

---

### Task 10: Apply the new config to the live tmux session (post-merge or post-direct-commit)

**Files:** none (runtime tmux only — interactive, requires the user)

**Context:** Editing the file does NOT change the running tmux server's behavior. The user must reload the config and install plugins from inside a tmux session. These steps cannot be performed by the agent because they require an interactive tmux client. Surface them clearly to the user.

- [ ] **Step 1: Tell the user to reload from inside tmux**

Show this instruction:

> From any tmux pane, press <kbd>C-a</kbd> then <kbd>r</kbd>. Status bar should briefly flash "config reloaded".

- [ ] **Step 2: Tell the user to install plugins via TPM**

Show:

> Press <kbd>C-a</kbd> then <kbd>I</kbd> (capital I — Shift+i). TPM clones the new plugins into `~/.config/tmux/plugins/`. (On this machine the directories already exist from before the trial, so it's likely a no-op — but on a fresh machine this is the install step.)

- [ ] **Step 3: Tell the user how to verify**

Show:

```bash
ls ~/.config/tmux/plugins/
```

Expected: includes `tmux-resurrect/` and `tmux-continuum/`.

Then from inside tmux:

> Press <kbd>C-a</kbd> then <kbd>C-s</kbd>. Status flashes "Tmux environment saved".

```bash
ls ~/.local/share/tmux/resurrect/ 2>/dev/null || ls ~/.tmux/resurrect/
```

Expected: at least one snapshot file (named like `tmux_resurrect_<timestamp>.txt`) exists.

- [ ] **Step 4: Auto-restore verification (OPTIONAL — disruptive)**

Mark as optional in the user-facing handoff. To verify auto-restore, the user must `tmux kill-server` and start a fresh tmux. This loses any in-flight scrollback/state, so most users will skip and just trust the config.

If the user wants to verify:

```bash
tmux kill-server
tmux
```

Expected: prior session shape returns automatically (sessions, windows, panes, layouts, working dirs). Programs that were running do NOT come back (this is expected — `@resurrect-processes` is unset).

---

## Notes on what's deliberately not in this plan

- **No `Brewfile` change.** TPM plugins are not Homebrew packages.
- **No `bootstrap.sh` change.** Bootstrap already clones TPM. Plugin install is a runtime concern handled by `<prefix> I`.
- **No CLAUDE.md change.** The "raw-tmux trial" note in CLAUDE.md doesn't exist (it's in the conf comments only); the project conventions list does not mention these plugins, so no doc drift to clean up there.
- **No `@continuum-boot 'on'`** (auto-start tmux at login). Out of scope per spec.
- **No new helper scripts or tests.** The existing `scripts/test-*.zsh` smoke tests don't cover plugin loading and shouldn't be extended ad hoc for this change.
