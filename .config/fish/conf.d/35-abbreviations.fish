# Fish abbreviations — type the abbreviation + Space/Enter and fish
# expands it inline before running. Better discoverability than aliases:
# you see what's actually being run, and `history` records the expansion.
#
# Conventions:
# - Git-flow shortcuts only for now. Mnemonic only — anything you'd want
#   to *see* before running (cat→bat, vim→nvim, ps→procs) stays an alias
#   in 30-aliases.fish; mnemonic shortcuts (gst, gco, gp) live here.
# - Since fish 3.6 abbreviations are per-shell (no longer universal vars),
#   so this file is the authoritative source — no manual `abbr -e` needed
#   to remove an entry, just delete the line and start a new shell.

abbr -a gst   git status
abbr -a gd    git diff
abbr -a gds   git diff --staged
abbr -a ga    git add
abbr -a gaa   git add -A
abbr -a gc    git commit
abbr -a gcm   git commit -m
abbr -a gcam  git commit -am
abbr -a gca   git commit --amend
abbr -a gco   git checkout
abbr -a gsw   git switch
abbr -a gcb   git checkout -b
abbr -a gb    git branch
abbr -a gp    git push
abbr -a gpf   git push --force-with-lease
abbr -a gpl   git pull
abbr -a gl    git log
abbr -a glo   git log --oneline
abbr -a gss   git stash
abbr -a grb   git rebase

# GitHub TUI dashboard (gh extension; installed by bootstrap.sh)
abbr -a ghd   gh dash

# Git worktrees (companion to the `wt` CLI)
abbr -a wtp   wt-primary
