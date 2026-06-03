function jnv --wraps jnv --description 'jnv with repo-managed (theme-set) config'
    # macOS jnv reads ~/Library/Application Support/jnv/config.toml via the dirs
    # crate (ignores XDG_CONFIG_HOME; no config-dir env var exists), so point it
    # at the theme-set-managed XDG config explicitly. On Linux/sandbox jnv already
    # defaults to ~/.config/jnv, so --config is a harmless no-op there. `command
    # jnv` is the escape hatch (unthemed Application Support default).
    #
    # jnv's clap rejects a repeated --config ("cannot be used multiple times"),
    # so skip our injection when the caller passed their own -c/--config.
    if string match -qr -- '^(-c|--config)(=.*)?$' $argv
        command jnv $argv
    else
        command jnv --config $HOME/.config/jnv/config.toml $argv
    end
end
