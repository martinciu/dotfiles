if command -q bat
    alias cat='bat --paging=never'
end

if command -q eza
    alias ls='eza --group-directories-first --icons'
    alias ll='eza -lh --git --icons --group-directories-first'
    alias la='ll -a'
end

# md / mdp live in functions/ (functions/md.fish) — they wrap glow at the
# current terminal width, which an alias can't compute per-invocation.

if command -q procs
    alias ps='procs'
    alias psh='procs --load-config $HOME/.config/procs/procs-heavy.toml'
end

if command -q nvim
    alias vim='nvim'
    alias vi='command vim'
    alias vimdiff='vim -d'
end

if command -q btop
    alias top='btop'
end

if command -q difft
    alias diff='difft'
end
