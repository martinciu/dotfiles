eval "$(/opt/homebrew/bin/brew shellenv)"

# Per-machine login-shell config (e.g. tools that aren't on every machine).
[[ -f ~/.zprofile.local ]] && source ~/.zprofile.local
