# Open the newest spec in .superpowers/specs with mdp.
#
# "Newest" = creation (birth) time via eza --sort=created, so the spec written
# most recently wins even if an older one was edited later. Relative to the
# current directory — run from the repo root. Spec filenames are date-prefixed,
# so `--sort=name` would usually agree, but creation time also orders multiple
# specs from the same day correctly.
function spec-last --description 'Open the newest .superpowers/specs doc in the pager'
    set -l files .superpowers/specs/*.md
    if not count $files >/dev/null
        echo "spec-last: no specs in .superpowers/specs/" >&2
        return 1
    end
    mdp (eza --sort=created --reverse $files | head -1)
end
