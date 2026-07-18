function slm --description 'One-off prompt to the local LM Studio model (qwen3.5)'
    set -l usage "slm — one-off prompt to the local LM Studio model

Usage:
  slm [-m <id>] [-s <prompt>] <prompt words...>
  cat file | slm [-m <id>] [-s <prompt>] [prompt words...]

Flags:
  -m, --model <id>    model id (default: \$SLM_MODEL or qwen/qwen3.5-9b)
  -s, --system <txt>  system prompt (default: \$SLM_SYSTEM or a terse built-in)
  -h, --help          show this help

Env:
  SLM_URL         base URL (default http://localhost:1234/v1)
  SLM_MODEL       default model id
  SLM_SYSTEM      default system prompt
  SLM_MAX_TOKENS  completion token cap (default 512)"

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
        set model qwen/qwen3.5-9b
    end

    set -l system
    if set -q _flag_system
        set system $_flag_system
    else if set -q SLM_SYSTEM
        set system $SLM_SYSTEM
    else
        set system "You are a terse assistant. Reply with only the answer, no preamble."
    end

    # Completion cap — qwen3.5 is a hybrid thinking model; uncapped it can
    # burn thousands of reasoning tokens on a one-liner task (#363). Numeric
    # guard so a garbage SLM_MAX_TOKENS falls back to 512 instead of feeding
    # jq --argjson a non-number.
    set -l max_tokens $SLM_MAX_TOKENS
    string match -qr '^[0-9]+$' -- "$max_tokens"; or set max_tokens 512

    # User message = args and/or piped stdin (instruction first, then the blob).
    # Read stdin only when it is not a TTY (mirrors less.fish). NOTE: in a
    # non-TTY context (script/cron/background) an arg-only call still reads
    # stdin, so callers there must redirect (e.g. `slm foo </dev/null`).
    # Capture via `(cat)` + `string join … | string collect` — NOT a bare
    # `(string collect)` (fish 4.7.1 no longer reads stdin from one). The
    # `| string collect` is what keeps the joined output as a single argument
    # — without it, command substitution re-splits on newlines, which both
    # collapses the body into space-joined fragments and exposes any line
    # starting with `-` to the next `string join` as a stray flag. `--` is
    # belt-and-braces in case a fragment ever starts with `-` after collect.
    set -l instruction (string join ' ' -- $argv)
    set -l piped ""
    if not isatty stdin
        set -l lines (cat)
        set piped (string join -- \n $lines | string collect)
    end

    set -l parts
    test -n "$instruction"; and set -a parts $instruction
    test -n "$piped"; and set -a parts $piped
    if test (count $parts) -eq 0
        echo $usage >&2
        return 2
    end
    set -l content (string join -- \n\n $parts | string collect)

    # Build the request body with jq (safe escaping); omit the system message
    # when its content is empty (e.g. `-s ""`). reasoning_effort "none" keeps
    # qwen's thinking off — without it a slug-sized prompt returns empty
    # content with the whole budget spent in reasoning_content (#363). Pipe
    # straight to curl so the JSON never round-trips through a fish variable.
    # `curl -s` (not -sS) so curl's own connection error doesn't double up
    # with our friendly message.
    set -l resp (jq -n --arg m "$model" --arg s "$system" --arg u "$content" --argjson t "$max_tokens" \
        '{model:$m, messages:((if $s=="" then [] else [{role:"system",content:$s}] end)+[{role:"user",content:$u}]), temperature:0.3, max_tokens:$t, reasoning_effort:"none", stream:false}' \
        | curl -s --connect-timeout 5 --max-time 120 \
            "$url/chat/completions" -H 'Content-Type: application/json' --data @-)
    set -l rc $status

    if test $rc -eq 7
        echo "slm: LM Studio not reachable at $url — is the LM Studio server running?" >&2
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
