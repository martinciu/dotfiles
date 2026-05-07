# s — completion for the worktree+session launcher (bin/s).
#
# Layout:
#   pos 1, outside tmux  -> sesh project names (excl. "Home 🏠")
#   pos 1, inside tmux   -> existing worktree branches in cwd's project
#   pos 2 (project given) -> existing worktree branches in that project
#
# File completion is disabled. Completions are non-exclusive — fresh names
# (e.g. `s 123-new-work`) still work and create a new worktree as before.

function __s_token_count
    # Positional-arg index the user is about to type. `commandline -opc`
    # returns parsed tokens up to (but excluding) the in-progress one, so
    # `s foo|` and `s |` both return 1 token; `s foo |` returns 2.
    set -l toks (commandline -opc)
    math (count $toks) - 1
end

function __s_projects
    sesh list -c -j 2>/dev/null \
        | jq -r '.[] | select(.Name != "Home 🏠") | .Name' 2>/dev/null
end

function __s_project_path -a name
    test -n "$name"; or return
    sesh list -c -j 2>/dev/null \
        | jq -r --arg n "$name" '.[] | select(.Name == $n) | .Path' 2>/dev/null \
        | head -n1
end

function __s_worktree_branches -a project_path
    # Emit branch names of *secondary* worktrees only — skip the primary
    # checkout (whose path equals project_path). `s <name>` creates/resumes
    # secondary worktrees; the primary's branch (whatever is currently
    # checked out at the project root) is not a valid target.
    test -n "$project_path"; or return
    git -C "$project_path" worktree list --porcelain 2>/dev/null \
        | awk -v project="$project_path" '
            $1=="worktree" {wt=$2}
            $1=="branch"   {sub("refs/heads/", "", $2); if (wt != project) print $2}
        '
end

function __s_cwd_project_path
    # Resolve cwd's project path even when inside a secondary worktree —
    # mirrors bin/s:105-109.
    set -l common (git -C "$PWD" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    test -n "$common"; or return
    pushd (dirname "$common") >/dev/null
    pwd -P
    popd >/dev/null
end

function __s_second_token
    set -l toks (commandline -opc)
    if test (count $toks) -ge 2
        echo $toks[2]
    end
end

# Disable file completion for `s` entirely.
complete -c s -f

# pos 1, outside tmux: project names.
complete -c s -n 'not set -q TMUX; and test (__s_token_count) -eq 0' \
    -a '(__s_projects)'

# pos 1, inside tmux: worktree branches of cwd's project.
complete -c s -n 'set -q TMUX; and test (__s_token_count) -eq 0' \
    -a '(__s_worktree_branches (__s_cwd_project_path))'

# pos 2 (project given): worktree branches of that project.
complete -c s -n 'test (__s_token_count) -eq 1' \
    -a '(__s_worktree_branches (__s_project_path (__s_second_token)))'
