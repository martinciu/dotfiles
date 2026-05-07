# Removing zsh

zsh is currently kept as a fallback while the fish transition settles. This
file lives until zsh is removed; deleting it is the last step of the
removal procedure (§2 step 10).

## §1 Pre-flight checks

Each row below is a known-zsh-only behavior that disappears when zsh is
removed. For each, decide *port to fish*, *accept the loss*, or *block
removal until fixed*. When every row is `accept` or `port` (none `block`),
removal is unblocked.

| # | Behavior | Currently | Decision |
|---|----------|-----------|----------|
| 1 | Ghostty tab title shows ` user@host` while ssh'd | zsh-only (`@ssh_target` hook in `.config/zsh/tmux-hooks.zsh`) | port / accept / block |
| 2 | `MODERN_REMINDER` discoverability nudge (`tail`/`tspin`, `grep`/`rg`, `curl`/`xh`) | zsh-only (`.config/zsh/modern-reminder.zsh`) | port / accept / block |
| 3 | fzf-tab style completion menu | zsh-only; fish has its own pager | already accepted |
| 4 | Starship transient prompt | fish-only on purpose; nothing to lose | n/a |
| 5 | Per-machine init that runs before `compinit` (`~/.zprofile.local`) | zsh-only | confirm content has migrated to `~/.config/fish/conf.d/15-local.fish` |
| 6 | Per-machine interactive overrides (`~/.zshrc.local`) | zsh-only | confirm content has migrated to `15-local.fish` (or `99-secrets.fish` if sensitive) |

## §2 Removal procedure

1. **Confirm pre-flight** — every row in §1 is `accept` or `port` (none `block`).
2. **Repo files to delete:**
   - `.zshrc`, `.zprofile`
   - `.zshrc.local.template`, `.zprofile.local.template`
   - `.config/zsh/` (entire directory)
   - `scripts/test-modern-reminder.zsh`
   - `scripts/test-tmux-window-label.zsh` (zsh variant; the fish equivalent
     `scripts/test-fish-tmux-window-label.fish` stays)
   - `scripts/test-tmux-ssh-target.zsh`
   - `scripts/test-claude-tmux-window-name.zsh` — audit before deleting. If
     it tests cross-shell behavior, port to bash; if zsh-only, delete.
3. **`bootstrap.sh`** — delete the `# --- zsh (fallback — see REMOVAL.md)`
   block (the four `link` calls for `.config/zsh`, `.zshrc`, `.zprofile`,
   `.config/starship.toml`). Keep the `starship.toml` link — fish uses it
   too. Move it into the fish block.
4. **`Brewfile`** — remove `zsh-syntax-highlighting`, `zsh-autosuggestions`,
   `fzf-tab`. Run
   `brew bundle cleanup --file=$PROJECTS_HOME/dotfiles/Brewfile` to
   uninstall.
5. **Machine-local files** (per machine):
   `rm ~/.zshrc ~/.zprofile ~/.zshrc.local ~/.zprofile.local`;
   `rm -rf ~/.config/zsh/` (these are repo symlinks; safe to remove).
6. **`/etc/shells`** — optional. Removing `/bin/zsh` is harmless to leave;
   only edit if you want to be tidy.
7. **System zsh (`/bin/zsh`)** — Apple-shipped, can't be uninstalled.
   Leave it.
8. **`CLAUDE.md`** — remove the "Zsh module layout (fallback)" subsection,
   remove the `.zprofile` bullet, drop `~/.zshrc.local` references in the
   env block, simplify the transient-prompt note ("fish has transient
   prompt; nothing else to qualify").
9. **`README.md`** — drop the "Fallback shell — zsh" subsection from
   "Manual extras"; drop the `~/.zshrc.local` line if still cited; drop
   the zsh row from the "What's where" table.
10. **Cheatsheets** — `docs/terminal-cheatsheet.html` and
    `docs/tmux-cheatsheet.html` carry zsh-specific references (plugin
    source order in `.zshrc`, `MODERN_REMINDER` toggle, `_tmux_window_label`
    location, plugin rows for `zsh-autosuggestions` /
    `zsh-syntax-highlighting` / `fzf-tab`, references to the zsh-only test
    scripts deleted in step 2). Audit both files and drop zsh-only content;
    refresh footer dates.
11. **Delete this file** — `rm REMOVAL.md` is the last commit.
