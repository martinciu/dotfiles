# zshrc Dotfiles Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Track `~/.zshrc` and `~/.p10k.zsh` in the dotfiles repo, clean up the config, split machine-specific settings into an untracked `~/.zshrc.local`, and wire everything into `bootstrap.sh`.

**Architecture:** A cleaned-up `.zshrc` lives in the repo and is symlinked to `~/.zshrc` by `bootstrap.sh`, same as existing dotfiles. Machine-specific config (conda, STM32, ghcup, Windsurf, opencode, CLAUDE_CODE_DISABLE_1M_CONTEXT) moves to an untracked `~/.zshrc.local` sourced at the end of `.zshrc`. A `.zshrc.local.template` in the repo serves as a reference for new machines.

**Tech Stack:** zsh, oh-my-zsh, Powerlevel10k, bootstrap.sh (bash)

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `dotfiles/.zshrc` | Portable shell config, symlinked to `~/.zshrc` |
| Create | `dotfiles/.p10k.zsh` | p10k prompt config, symlinked to `~/.p10k.zsh` |
| Create | `dotfiles/.zshrc.local.template` | Reference template for machine-specific overrides, not symlinked |
| Create (local only) | `~/.zshrc.local` | Machine-specific config, never committed |
| Modify | `dotfiles/bootstrap.sh` | Add symlinks for `.zshrc` and `.p10k.zsh`; add next-step note |

---

## Task 1: Create `.zshrc` in repo

**Files:**
- Create: `dotfiles/.zshrc`

- [ ] **Step 1: Write `dotfiles/.zshrc`**

Create `dotfiles/.zshrc` with this exact content:

```zsh
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export EDITOR=vim

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git nvm brew rbenv node)

source $ZSH/oh-my-zsh.sh

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

export PATH="$HOME/.cargo/bin:$PATH"
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
export PATH="$HOME/.local/bin:$PATH"

export PROJECTS_HOME="$HOME/code"

autoload -U add-zsh-hook
load-nvmrc() {
  local node_version="$(nvm version)"
  local nvmrc_path="$(nvm_find_nvmrc)"

  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$node_version" ]; then
      nvm use
    fi
  elif [ "$node_version" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}
add-zsh-hook chpwd load-nvmrc
load-nvmrc

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
[[ -f ~/.secrets ]] && source ~/.secrets
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
```

What changed vs the current `~/.zshrc`:
- Removed manual NVM block (lines 34–36) — the `nvm` oh-my-zsh plugin already loads NVM
- Removed conda block — moves to `.zshrc.local`
- Removed STM32, ghcup, Windsurf, opencode, `CLAUDE_CODE_DISABLE_1M_CONTEXT` — move to `.zshrc.local`
- Replaced all `/Users/martinciu/` with `$HOME`
- Removed `PROJECTS_ROOT` (redundant with `PROJECTS_HOME`)
- Added `[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local` at end

- [ ] **Step 2: Verify zsh syntax**

```bash
zsh -n dotfiles/.zshrc
```

Expected: no output, exit code 0.

- [ ] **Step 3: Commit**

```bash
git -C ~/code/dotfiles add .zshrc
git -C ~/code/dotfiles commit -m "feat(zsh): add .zshrc to dotfiles"
```

---

## Task 2: Copy `.p10k.zsh` into repo

**Files:**
- Create: `dotfiles/.p10k.zsh`

- [ ] **Step 1: Copy the current p10k config**

```bash
cp ~/.p10k.zsh ~/code/dotfiles/.p10k.zsh
```

- [ ] **Step 2: Verify it copied cleanly**

```bash
diff ~/.p10k.zsh ~/code/dotfiles/.p10k.zsh
```

Expected: no output (files identical).

- [ ] **Step 3: Commit**

```bash
git -C ~/code/dotfiles add .p10k.zsh
git -C ~/code/dotfiles commit -m "feat(zsh): add .p10k.zsh to dotfiles"
```

---

## Task 3: Create `.zshrc.local.template`

**Files:**
- Create: `dotfiles/.zshrc.local.template`

- [ ] **Step 1: Write `dotfiles/.zshrc.local.template`**

Create `dotfiles/.zshrc.local.template` with this content:

```zsh
# Machine-specific shell config.
# Copy to ~/.zshrc.local and uncomment/fill in what applies to this machine.
# This file is NOT tracked by dotfiles — never commit ~/.zshrc.local.

# conda/miniconda — run 'conda init zsh' to regenerate this block for your install path
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
# __conda_setup="$('/path/to/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
# if [ $? -eq 0 ]; then
#     eval "$__conda_setup"
# else
#     if [ -f "/path/to/miniconda3/etc/profile.d/conda.sh" ]; then
#         . "/path/to/miniconda3/etc/profile.d/conda.sh"
#     else
#         export PATH="/path/to/miniconda3/bin:$PATH"
#     fi
# fi
# unset __conda_setup
# <<< conda initialize <<<

# STM32CubeProgrammer
# export STM32_PRG_PATH=/Applications/STMicroelectronics/STM32Cube/STM32CubeProgrammer/STM32CubeProgrammer.app/Contents/MacOs/bin

# ghcup (Haskell toolchain)
# source "${HOME}/.ghcup/env"

# Windsurf
# export PATH="${HOME}/.codeium/windsurf/bin:$PATH"

# opencode
# export PATH="${HOME}/.opencode/bin:$PATH"

# Claude Code — disable 1M context window
# export CLAUDE_CODE_DISABLE_1M_CONTEXT=1
```

- [ ] **Step 2: Commit**

```bash
git -C ~/code/dotfiles add .zshrc.local.template
git -C ~/code/dotfiles commit -m "feat(zsh): add .zshrc.local.template"
```

---

## Task 4: Create `~/.zshrc.local` on this machine

**Files:**
- Create (local only, not committed): `~/.zshrc.local`

- [ ] **Step 1: Write `~/.zshrc.local`**

Create `~/.zshrc.local` with the machine-specific items extracted from the old `~/.zshrc`:

```zsh
# Machine-specific config for this machine — not tracked in dotfiles.

# conda/miniconda
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/martinciu/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/martinciu/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/martinciu/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/martinciu/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export STM32_PRG_PATH=/Applications/STMicroelectronics/STM32Cube/STM32CubeProgrammer/STM32CubeProgrammer.app/Contents/MacOs/bin

source "${HOME}/.ghcup/env"

export PATH="${HOME}/.codeium/windsurf/bin:$PATH"

export PATH="${HOME}/.opencode/bin:$PATH"

export CLAUDE_CODE_DISABLE_1M_CONTEXT=1
```

- [ ] **Step 2: Verify zsh syntax**

```bash
zsh -n ~/.zshrc.local
```

Expected: no output, exit code 0.

- [ ] **Step 3: Confirm it is NOT tracked**

```bash
git -C ~/code/dotfiles status
```

Expected: `~/.zshrc.local` does not appear — it lives outside the repo.

---

## Task 5: Update `bootstrap.sh`

**Files:**
- Modify: `dotfiles/bootstrap.sh`

- [ ] **Step 1: Add symlink calls**

In `dotfiles/bootstrap.sh`, after the `# --- vim` section (after the `mkdir -p "$HOME/.vim/undo"...` line), add:

```bash
# --- zsh
link ".zshrc"     "$HOME/.zshrc"
link ".p10k.zsh"  "$HOME/.p10k.zsh"
```

- [ ] **Step 2: Add next-step note**

In the `next steps` echo block at the bottom, add a new item:

```bash
echo "  4. create machine config:    cp \$DOTFILES/.zshrc.local.template ~/.zshrc.local && \$EDITOR ~/.zshrc.local"
```

The full updated block should look like:

```bash
echo
echo "next steps:"
echo "  1. start tmux:               tmux"
echo "  2. install plugins:          <prefix> I  (capital I, prefix = C-a)"
echo "  3. test sesh popup:          <prefix> T"
echo "  4. create machine config:    cp \$DOTFILES/.zshrc.local.template ~/.zshrc.local && \$EDITOR ~/.zshrc.local"
```

- [ ] **Step 3: Verify bash syntax**

```bash
bash -n ~/code/dotfiles/bootstrap.sh
```

Expected: no output, exit code 0.

- [ ] **Step 4: Commit**

```bash
git -C ~/code/dotfiles add bootstrap.sh
git -C ~/code/dotfiles commit -m "feat(bootstrap): symlink .zshrc and .p10k.zsh"
```

---

## Task 6: Run bootstrap and verify

- [ ] **Step 1: Back up current `~/.zshrc` and `~/.p10k.zsh`**

```bash
cp ~/.zshrc ~/.zshrc.bak
cp ~/.p10k.zsh ~/.p10k.zsh.bak
```

- [ ] **Step 2: Run bootstrap**

```bash
bash ~/code/dotfiles/bootstrap.sh
```

Expected output includes:

```
linked: /Users/martinciu/.zshrc -> /Users/martinciu/code/dotfiles/.zshrc
linked: /Users/martinciu/.p10k.zsh -> /Users/martinciu/code/dotfiles/.p10k.zsh
```

(Or `ok:` if the symlinks were already in place.)

- [ ] **Step 3: Verify symlinks point to repo**

```bash
readlink ~/.zshrc
readlink ~/.p10k.zsh
```

Expected:
```
/Users/martinciu/code/dotfiles/.zshrc
/Users/martinciu/code/dotfiles/.p10k.zsh
```

- [ ] **Step 4: Source the new config in a subshell to check for errors**

```bash
zsh -i -c 'echo "zshrc loaded OK"' 2>&1
```

Expected: `zshrc loaded OK` with no error lines. (p10k instant-prompt warnings about non-interactive init are benign.)

- [ ] **Step 5: Open a new terminal and confirm the prompt loads**

Open a new Ghostty window or tab. Verify:
- Powerlevel10k prompt renders correctly
- `echo $PROJECTS_HOME` prints `/Users/martinciu/code`
- `echo $NVM_DIR` is set (NVM loaded via oh-my-zsh plugin)
- `conda` command is available (loaded from `.zshrc.local`)

- [ ] **Step 6: Clean up backup files**

```bash
rm ~/.zshrc.bak ~/.p10k.zsh.bak
```
