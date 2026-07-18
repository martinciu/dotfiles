# Theme names (first arg). Mirrors completions/theme-set.fish.
complete -c moshi-theme -f -n 'test (count (commandline -opc)) -eq 1' -a solarized      -d 'Solarized Dark (default)'
complete -c moshi-theme -f -n 'test (count (commandline -opc)) -eq 1' -a mocha          -d 'Catppuccin Mocha'
complete -c moshi-theme -f -n 'test (count (commandline -opc)) -eq 1' -a frappe         -d 'Catppuccin Frappé'
complete -c moshi-theme -f -n 'test (count (commandline -opc)) -eq 1' -a dracula        -d 'Dracula'
complete -c moshi-theme -f -n 'test (count (commandline -opc)) -eq 1' -a gruvbox        -d 'Gruvbox'
complete -c moshi-theme -f -n 'test (count (commandline -opc)) -eq 1' -a tokyo-night    -d 'Tokyo Night Storm'
complete -c moshi-theme -f -n 'test (count (commandline -opc)) -eq 1' -a nord           -d 'Nord'
complete -c moshi-theme -f -n 'test (count (commandline -opc)) -eq 1' -a latte          -d 'Catppuccin Latte (light)'
complete -c moshi-theme -f -n 'test (count (commandline -opc)) -eq 1' -a rose-pine      -d 'Rosé Pine'
complete -c moshi-theme -f -n 'test (count (commandline -opc)) -eq 1' -a rose-pine-moon -d 'Rosé Pine Moon'

complete -c moshi-theme -l qr -d 'Render a scannable QR (phone camera → Moshi import)'
complete -c moshi-theme -s h -l help -d 'Show usage'
