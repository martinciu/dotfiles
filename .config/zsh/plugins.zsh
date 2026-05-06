# ─── Plugins (order matters) ─────────────────────────────────────
# Required order:
#   fzf shell integration  → binds ^I; must come first so subsequent
#                            plugins that wrap completion can chain to it
#   Alt-C unbind           → adjacent to fzf since it removes a binding fzf set
#   zoxide                 → independent; doesn't bind ^I or wrap widgets
#   fzf-tab                → after fzf integration (loses ^I race otherwise),
#                            before autosuggestions/syntax-highlighting
#   wt shell init          → eval'd here (same family as zoxide init)
#   zsh-autosuggestions    → wraps widgets; must be after fzf integration
#   zsh-syntax-highlighting → MUST be last (wraps every other widget)
#
# All side-effect; tests don't source this file.
[[ -n ${ZSH_DOTFILES_TEST:-} ]] && return

# fzf shell integration (Ctrl-R history, Ctrl-T file picker).
[[ -f /opt/homebrew/opt/fzf/shell/completion.zsh ]] && \
  source /opt/homebrew/opt/fzf/shell/completion.zsh
[[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]] && \
  source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
# Alt-C is reserved for Polish diacritics; remove fzf's cd-widget binding in
# every keymap fzf might have bound it in.
bindkey -M emacs -r '^[c' 2>/dev/null
bindkey -M viins -r '^[c' 2>/dev/null
bindkey -M vicmd -r '^[c' 2>/dev/null

# zoxide — frecency-ranked `cd` (`z foo`). The sesh picker no longer
# reads zoxide (see tmux.conf: `sesh picker ... -c -t -T`), so these
# excludes exist purely for `z` discipline: `z lib` should not jump
# into ~/Library, `z config` should not jump into ~/.config, etc.
# _ZO_EXCLUDE_DIRS is colon-separated globs (per `man zoxide`).
if command -v zoxide >/dev/null 2>&1; then
  export _ZO_EXCLUDE_DIRS="$HOME:$HOME/Downloads/*:$HOME/.config/*:$HOME/Library/*"
  eval "$(zoxide init zsh)"
fi

# fzf-tab — replace zsh's default completion menu with fzf.
# Must be sourced AFTER fzf shell integration (loses ^I race otherwise) and
# BEFORE zsh-autosuggestions / zsh-syntax-highlighting (both wrap widgets).
[[ -f /opt/homebrew/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh ]] && \
  source /opt/homebrew/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh
# fzf-tab needs `menu select` disabled to capture completions.
zstyle ':completion:*' menu no
# Group completions by tag with a labeled header.
zstyle ':completion:*:descriptions' format '[%d]'
# Filename colors in the picker — inherit vivid's Solarized palette via LS_COLORS.
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# Inherit FZF_DEFAULT_OPTS so the picker matches Ctrl-R / Ctrl-T styling.
zstyle ':fzf-tab:*' use-fzf-default-opts yes
# Switch between completion groups.
zstyle ':fzf-tab:*' switch-group '<' '>'
# Preview directory contents when completing `cd`.
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath'

# worktrunk shell init (defines `wt switch` shell-side plumbing).
if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi

[[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-syntax-highlighting MUST be the last sourced plugin.
[[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
