#!/usr/bin/env fish
# Tests for the modern-reminder fish module.
# Run: fish scripts/test-modern-reminder.fish
set -l pass 0
set -l fail 0
set -l fail_msgs

function assert_contains --argument-names got needle desc
    if string match -q "*$needle*" -- "$got"
        set pass (math $pass + 1)
        echo "  PASS  $desc"
    else
        set fail (math $fail + 1)
        set -a fail_msgs "FAIL  $desc"\n"        got:    '$got'"\n"        needle: '$needle'"
        echo "  FAIL  $desc"
    end
end

function assert_not_contains --argument-names got needle desc
    if not string match -q "*$needle*" -- "$got"
        set pass (math $pass + 1)
        echo "  PASS  $desc"
    else
        set fail (math $fail + 1)
        set -a fail_msgs "FAIL  $desc"\n"        got contained: '$needle'"
        echo "  FAIL  $desc"
    end
end

# Locate repo and source the real module under test guard
set -l REPO (realpath (dirname (status filename))/..)
set -gx MODERN_REMINDER_TEST 1
source "$REPO/.config/fish/conf.d/50-modern-reminder.fish"
set -e MODERN_REMINDER_TEST

echo
echo "modern-reminder (fish)"

# helper: clear seen set, run scan, capture stdout
function _run --argument-names cmdline
    set -g _modern_reminder_seen
    _modern_reminder_scan $cmdline
end

# Test 1: disabled when env var unset
set -e MODERN_REMINDER
set out (_run "grep TODO src/" 2>&1)
assert_not_contains "$out" "modern alternative" "MODERN_REMINDER unset -> no reminder"

# Test 2: fires once per session
set -gx MODERN_REMINDER 1
set -g _modern_reminder_seen
set out1 (_modern_reminder_scan "grep TODO src/"   2>&1)
set out2 (_modern_reminder_scan "grep TODO other/" 2>&1)
assert_contains "$out1" "rg is a modern alternative to grep" "First grep call -> reminder fires"
assert_not_contains "$out2" "modern alternative" "Second grep call in same shell -> silent"

# Test 3: skips when modern tool missing
set -gx MODERN_REMINDER 1
set -g _modern_reminder_seen
set -l saved_path $PATH
set -gx PATH /nonexistent
set out (_run "grep TODO src/" 2>&1)
set -gx PATH $saved_path
assert_not_contains "$out" "modern alternative" "Modern tool missing from \$PATH -> no reminder"

# Test 4: token scan handles pipes
set -gx MODERN_REMINDER 1
set out (_run "echo x | grep x" 2>&1)
assert_contains "$out" "rg is a modern alternative to grep" "Token scan: 'echo x | grep x' fires for grep"

# Test 5: tail hint sample-syntax preserved (no command substitution)
set -gx MODERN_REMINDER 1
set out (_run "tail /etc/hosts" 2>&1)
assert_contains "$out" "Try 'tspin -f app.log'." "tail hint: literal sample syntax preserved"

# Test 6: backslash-escaped command (\tail) basename-matches
set -gx MODERN_REMINDER 1
set out (_run "\\tail foo.log" 2>&1)
assert_contains "$out" "tspin is a modern alternative to tail" "Backslash-escaped tail -> basename match fires"

# Test 7: absolute-path command (/usr/bin/tail) basename-matches
set -gx MODERN_REMINDER 1
set out (_run "/usr/bin/tail foo.log" 2>&1)
assert_contains "$out" "tspin is a modern alternative to tail" "Absolute-path tail -> basename match fires"

# Test 8: fresh subshell starts empty (validates per-process scope)
set -l out_a (fish -N -c "set -gx MODERN_REMINDER_TEST 1; source $REPO/.config/fish/conf.d/50-modern-reminder.fish; set -e MODERN_REMINDER_TEST; set -gx MODERN_REMINDER 1; _modern_reminder_scan 'grep TODO'" 2>&1)
set -l out_b (fish -N -c "set -gx MODERN_REMINDER_TEST 1; source $REPO/.config/fish/conf.d/50-modern-reminder.fish; set -e MODERN_REMINDER_TEST; set -gx MODERN_REMINDER 1; _modern_reminder_scan 'grep TODO'" 2>&1)
assert_contains "$out_a" "modern alternative to grep" "Subshell A: grep fires reminder"
assert_contains "$out_b" "modern alternative to grep" "Subshell B (fresh process): grep fires again — no shared state"

echo
echo "Total: "(math $pass + $fail)"  pass: $pass  fail: $fail"
if test $fail -gt 0
    for msg in $fail_msgs
        echo
        echo $msg
    end
    exit 1
end
exit 0
