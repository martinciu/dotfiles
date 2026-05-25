# i — completion for the issue→worktree launcher (bin/i).
#
#   pos 1  -> open GitHub issues in cwd's repo (number + title), via `gh`.
#   pos 2+ -> slug / free text, no completion.
#
# File completion is disabled. Network-backed (gh), so it's a deliberate tab —
# bounded with --limit to keep it snappy.

function __i_token_count
    # Positional-arg index the user is about to type (mirrors __s_token_count).
    set -l toks (commandline -opc)
    math (count $toks) - 1
end

function __i_open_issues
    # "<number>\t<title>" — fish shows the number as the candidate and the
    # title as its description.
    gh issue list --state open --limit 50 --json number,title 2>/dev/null \
        | jq -r '.[] | "\(.number)\t\(.title)"' 2>/dev/null
end

# Disable file completion for `i`.
complete -c i -f

# pos 1: open issue numbers (titles as descriptions).
complete -c i -n 'test (__i_token_count) -eq 0' -a '(__i_open_issues)'
