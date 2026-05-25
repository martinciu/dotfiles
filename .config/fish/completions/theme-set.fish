complete -c theme-set -f -n 'test (count (commandline -opc)) -eq 1' -a solarized   -d 'Solarized Dark (default)'
complete -c theme-set -f -n 'test (count (commandline -opc)) -eq 1' -a mocha       -d 'Catppuccin Mocha'
complete -c theme-set -f -n 'test (count (commandline -opc)) -eq 1' -a dracula     -d 'Dracula'
complete -c theme-set -f -n 'test (count (commandline -opc)) -eq 1' -a gruvbox     -d 'Gruvbox Dark Medium'
complete -c theme-set -f -n 'test (count (commandline -opc)) -eq 1' -a tokyo-night -d 'Tokyo Night Storm'
complete -c theme-set -f -n 'test (count (commandline -opc)) -eq 1' -a nord        -d 'Nord'
complete -c theme-set -f -n 'test (count (commandline -opc)) -eq 1' -a latte       -d 'Catppuccin Latte (light)'
complete -c theme-set -f -n 'test (count (commandline -opc)) -eq 1' -a rose-pine   -d 'Rose Pine Main'
complete -c theme-set -f -n 'test (count (commandline -opc)) -eq 1' -a rose-pine-moon -d 'Rose Pine Moon (2.5 contrast)'

# Flags (no positional name yet, or alongside).
complete -c theme-set -l stats -d 'Per-theme usage report'
complete -c theme-set -l all   -d 'Include sub-minute selections in --stats'
complete -c theme-set -s h -l help -d 'Show usage'
