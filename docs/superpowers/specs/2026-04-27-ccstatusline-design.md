# Add ccstatusline config to dotfiles

## Goal

Track `~/.config/ccstatusline/` in the dotfiles repo and deploy it via `bootstrap.sh`, consistent with how `ghostty` and `tmux` configs are managed.

## Changes

### 1. Copy config into repo

Copy the live `~/.config/ccstatusline/` directory into the repo as `.config/ccstatusline/`. This captures the current `settings.json` under version control.

### 2. Add symlink to bootstrap.sh

Add one line in the `# --- ccstatusline` section of `bootstrap.sh`:

```bash
link ".config/ccstatusline" "$HOME/.config/ccstatusline"
```

Placement: after the tmux block, before the TPM block.

### 3. Replace live directory with symlink

On first `bootstrap.sh` run after this change, the script backs up the real `~/.config/ccstatusline` directory (appending `.bak.<timestamp>`) and replaces it with a symlink pointing to `$DOTFILES/.config/ccstatusline`.

## Scope

- Single file currently in the directory: `settings.json`
- Any future files ccstatusline writes to `~/.config/ccstatusline/` will automatically be tracked since the whole directory is symlinked
- No new tooling or patterns introduced — follows the existing `link()` idiom exactly
