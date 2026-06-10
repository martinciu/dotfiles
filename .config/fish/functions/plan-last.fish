# Open the newest plan in .superpowers/plans with mdp.
#
# "Newest" = creation (birth) time via eza --sort=created, so the plan written
# most recently wins even if an older one was edited later. Relative to the
# current directory — run from the repo root. Plan filenames are date-prefixed,
# so `--sort=name` would usually agree, but creation time also orders multiple
# plans from the same day correctly.
function plan-last --description 'Open the newest .superpowers/plans doc in the pager'
    set -l files .superpowers/plans/*.md
    if not count $files >/dev/null
        echo "plan-last: no plans in .superpowers/plans/" >&2
        return 1
    end
    mdp (eza --sort=created --reverse $files | head -1)
end
