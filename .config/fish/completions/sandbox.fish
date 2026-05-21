# Completions for the `sandbox` command (bin/sandbox).
# Mirrors the s.fish / wt.fish style: subcommand-aware, dynamic name lists.

function __sandbox_names
    docker ps -a --filter label=sandbox=1 --format '{{.Names}}' 2>/dev/null \
        | string replace -r '^sandbox-' ''
end

function __sandbox_needs_command
    set -l cmd (commandline -opc)
    test (count $cmd) -eq 1
end

# Top-level verbs (only when no subcommand typed yet).
complete -c sandbox -n __sandbox_needs_command -f -a build -d 'Build/rebuild the image'
complete -c sandbox -n __sandbox_needs_command -f -a ls -d 'List sandboxes'
complete -c sandbox -n __sandbox_needs_command -f -a stop -d 'Stop a sandbox (keep volume)'
complete -c sandbox -n __sandbox_needs_command -f -a rm -d 'Remove a sandbox + volume'
complete -c sandbox -n __sandbox_needs_command -f -a machine -d 'OrbStack machine (trusted only)'
# Existing sandbox names are also valid first args (reattach).
complete -c sandbox -n __sandbox_needs_command -f -a '(__sandbox_names)' -d 'sandbox'

# Name args for stop/rm.
complete -c sandbox -n '__fish_seen_subcommand_from stop rm' -f -a '(__sandbox_names)'

# machine subcommands.
complete -c sandbox -n '__fish_seen_subcommand_from machine' -f -a 'create ssh rm'

# Flags (available after a name is given).
complete -c sandbox -l rm -d 'Ephemeral throwaway'
complete -c sandbox -s p -d 'Publish PORT to 127.0.0.1' -x
complete -c sandbox -l mount -d 'Bind-mount ONE dir' -r
complete -c sandbox -l env-file -d 'Pass an env file' -r
complete -c sandbox -s e -d 'Pass KEY=VAL' -x
complete -c sandbox -l memory -d 'Memory limit' -x
complete -c sandbox -l cpus -d 'CPU limit' -x
