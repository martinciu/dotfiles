function jnv --wraps jnv --description 'jnv with repo-managed (theme-set) config'
    # macOS jnv reads ~/Library/Application Support/jnv/config.toml via the dirs
    # crate (ignores XDG_CONFIG_HOME; no config-dir env var exists), so point it
    # at the theme-set-managed XDG config explicitly. On Linux/sandbox jnv already
    # defaults to ~/.config/jnv, so --config is a harmless no-op there. `command
    # jnv` is the escape hatch (unthemed Application Support default).
    command jnv --config $HOME/.config/jnv/config.toml $argv
end
