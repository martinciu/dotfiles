# bat-backed less wrapper. Direct port of the zsh function in aliases.zsh.
function less
    if isatty stdin
        command bat --paging=always $argv
    else
        command bat --paging=always --plain $argv
    end
end
