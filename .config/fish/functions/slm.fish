function slm --description 'One-off prompt to the local LM Studio model (lfm2.5)'
    set -l usage "slm — one-off prompt to the local LM Studio model

Usage:
  slm [-m <id>] [-s <prompt>] <prompt words...>
  cat file | slm [-m <id>] [-s <prompt>] [prompt words...]

Flags:
  -m, --model <id>    model id (default: \$SLM_MODEL or lfm2.5-1.2b-instruct)
  -s, --system <txt>  system prompt (default: \$SLM_SYSTEM or a terse built-in)
  -h, --help          show this help

Env:
  SLM_URL     base URL (default http://localhost:1234/v1)
  SLM_MODEL   default model id
  SLM_SYSTEM  default system prompt"

    argparse m/model= s/system= h/help -- $argv
    or return 2

    if set -q _flag_help
        echo $usage
        return 0
    end

    # Config: flag > env > built-in default.
    set -l url $SLM_URL
    test -n "$url"; or set url http://localhost:1234/v1

    set -l model
    if set -q _flag_model
        set model $_flag_model
    else if set -q SLM_MODEL; and test -n "$SLM_MODEL"
        set model $SLM_MODEL
    else
        set model lfm2.5-1.2b-instruct
    end

    set -l system
    if set -q _flag_system
        set system $_flag_system
    else if set -q SLM_SYSTEM
        set system $SLM_SYSTEM
    else
        set system "You are a terse assistant. Reply with only the answer, no preamble."
    end

    # User message = args and/or piped stdin (instruction first, then the blob).
    # Read stdin only when it is not a TTY (mirrors less.fish). NOTE: in a
    # non-TTY context (script/cron/background) an arg-only call still reads
    # stdin, so callers there must redirect (e.g. `slm foo </dev/null`).
    # Capture via `(cat)` + `string join` — NOT `string collect` (fish 4.7.1
    # no longer reads stdin from a bare `string collect`).
    set -l instruction (string join ' ' -- $argv)
    set -l piped ""
    if not isatty stdin
        set -l lines (cat)
        set piped (string join \n $lines)
    end

    set -l parts
    test -n "$instruction"; and set -a parts $instruction
    test -n "$piped"; and set -a parts $piped
    if test (count $parts) -eq 0
        echo $usage >&2
        return 2
    end
    set -l content (string join \n\n $parts)

    # Build the request body with jq (safe escaping); omit the system message
    # when its content is empty (e.g. `-s ""`). Pipe straight to curl so the
    # JSON never round-trips through a fish variable. `curl -s` (not -sS) so
    # curl's own connection error doesn't double up with our friendly message.
    set -l resp (jq -n --arg m "$model" --arg s "$system" --arg u "$content" \
        '{model:$m, messages:((if $s=="" then [] else [{role:"system",content:$s}] end)+[{role:"user",content:$u}]), temperature:0.3, stream:false}' \
        | curl -s --connect-timeout 5 --max-time 120 \
            "$url/chat/completions" -H 'Content-Type: application/json' --data @-)
    set -l rc $status

    if test $rc -eq 7
        echo "slm: LM Studio not reachable at $url — run 'lms server start'" >&2
        return 1
    else if test $rc -ne 0
        echo "slm: request failed (curl exit $rc)" >&2
        return 1
    end

    # Extract the completion; fall back to the API error, then a generic message.
    set -l out (printf '%s\n' $resp | jq -r '.choices[0].message.content // empty')
    if test -z "$out"
        set -l errmsg (printf '%s\n' $resp | jq -r '.error.message // empty')
        if test -n "$errmsg"
            echo "slm: $errmsg" >&2
        else
            echo "slm: no response from $model" >&2
        end
        return 1
    end

    printf '%s\n' $out
end
