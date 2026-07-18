function moshi-theme --description 'Export a dotfiles theme to the Moshi iPhone terminal (active theme by default)'
    set -l usage "Usage: moshi-theme [<theme>] [--qr]
       moshi-theme           export the active theme (theme-set's pick)
       moshi-theme <name>    export a specific theme
       --qr                  also render a scannable QR (needs qrencode)

Phone side: Settings → Theme → Import theme (paste / scan), or tap the
moshi:// link when running inside Moshi."

    if contains -- -h $argv; or contains -- --help $argv
        echo $usage
        return 0
    end

    set -l qr 0
    set -l name
    for a in $argv
        switch $a
            case --qr
                set qr 1
            case '-*'
                echo $usage >&2
                return 1
            case '*'
                set name $a
        end
    end

    if test -z "$name"
        set name (__theme_set_current)
        if test -z "$name"
            echo "moshi-theme: no active theme found — run theme-set, or pass a name" >&2
            return 1
        end
    end

    if not contains -- $name (__theme_set_names)
        echo $usage >&2
        return 1
    end

    set -l json ~/.config/themes/moshi-$name.json
    if not test -e $json
        echo "moshi-theme: $json missing — re-run bootstrap.sh to link it" >&2
        return 1
    end

    # Minify, then base64 (single line — `string join` guards GNU wrapping).
    set -l b64 (jq -c . $json | base64 | string join '')
    set -l link "moshi://theme?d=$b64"

    echo "$name → Moshi"
    echo "  tap (from Moshi):  $link"

    if test $qr -eq 1
        if command -v qrencode >/dev/null
            qrencode -t ansiutf8 -- $link
        else
            echo "moshi-theme: qrencode not installed (brew install qrencode) — skipping QR" >&2
        end
    end

    if command -v pbcopy >/dev/null
        printf '%s' "moshi-theme:$b64" | pbcopy
        echo "  copied:            moshi-theme:… string → clipboard ✓"
    else
        echo "  paste string:      moshi-theme:$b64"
    end
end
