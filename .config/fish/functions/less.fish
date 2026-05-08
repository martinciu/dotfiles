# bat-backed less wrapper.
function less
    if isatty stdin
        command bat --paging=always $argv
    else
        command bat --paging=always --plain $argv
    end
end
