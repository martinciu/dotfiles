function wt-primary --description 'Print the primary worktree root (works from any worktree of the current repo)'
    # Bulletproof against --separate-git-dir: the first entry in
    # `git worktree list --porcelain` is always the primary checkout.
    set -l primary (git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')
    if test -z "$primary"
        return 1
    end
    echo $primary
end
