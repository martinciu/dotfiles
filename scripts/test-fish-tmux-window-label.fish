#!/usr/bin/env fish
# Unit tests for _tmux_window_label (fish port).
# Run: fish scripts/test-fish-tmux-window-label.fish

set -gx FISH_DOTFILES_TEST 1
set -e TMUX

set -l REPO (cd (dirname (status filename))/..; and pwd)
source $REPO/.config/fish/conf.d/50-tmux-hooks.fish

set -g pass 0
set -g fail 0
set -g fail_msgs

function check_label --argument-names input want desc
    set -l got (_tmux_window_label $input)
    if test "$got" = "$want"
        set -g pass (math $pass + 1)
        echo "  PASS  $desc"
    else
        set -g fail (math $fail + 1)
        set -ga fail_msgs "FAIL  $desc"
        set -ga fail_msgs "        got:  '$got'"
        set -ga fail_msgs "        want: '$want'"
        echo "  FAIL  $desc"
    end
end

echo
echo "_tmux_window_label"
echo "──────────────────"

check_label "git push origin main" "git push" "two-word command → first two words"
check_label "RAILS_ENV=test bundle exec rspec spec/foo" "bundle exec" "leading env var stripped"
check_label "DEBUG=1 npm run dev" "npm run" "single env var + multi-word command"
check_label "BUNDLE_GEMFILE=Gemfile.next RAILS_ENV=test bundle exec rspec" "bundle exec" "two leading env vars stripped"
check_label "nvim" "nvim" "single-word command"
check_label "git log | head -5" "git log" "pipe → first two whitespace-separated tokens"
check_label "cd ~/projects" "cd ~/projects" "cd with single arg → both words"
check_label "" "" "empty input → empty label"
check_label "FOO=bar" "" "env var alone → empty label"
check_label "FOO=bar BAZ=qux ls -la" "ls -la" "multiple env vars → stripped, then first two words"
check_label "  git   status  " "git status" "extra whitespace collapses"

echo
echo "──────────────────"
echo "passed: $pass"
echo "failed: $fail"
if test $fail -gt 0
    echo
    printf '%s\n' $fail_msgs
    exit 1
end
exit 0
