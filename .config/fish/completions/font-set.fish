# 1st positional: font short name
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a jetbrains   -d 'JetBrains Mono (default; ligatures)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a fira        -d 'FiraCode (ligatures)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a cascadia    -d 'Cascadia Code / CaskaydiaCove (ligatures)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a monaspace   -d 'GitHub Monaspace Neon (ligatures)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a iosevka     -d 'Iosevka (ligatures; narrow)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a hack        -d 'Hack (no ligatures; classic)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a meslo       -d 'MesloLGS (no ligatures; Powerlevel10k default)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a sauce       -d 'SauceCodePro / Source Code Pro (no ligatures)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a ubuntu      -d 'UbuntuMono (no ligatures)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a inconsolata -d 'Inconsolata (no ligatures)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a departure   -d 'DepartureMono (pixel display; no ligatures)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a bigblue     -d 'BigBlueTermPlus (IBM CP437 pixel bitmap)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a 0xproto     -d '0xProto (ligatures)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a 3270        -d '3270 (IBM mainframe terminal; tall, narrow)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a hurmit      -d 'Hurmit / Hermit (minimalist humanist; no ligatures)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a monofur     -d 'Monofur (hand-drawn curves; no ligatures)'
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 1' -a dyslexic    -d 'OpenDyslexicM (weighted bottoms; dyslexia-aware)'

# 2nd positional: weight — depends on font picked in arg 1.
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 2' \
    -a '(__font_set_weights_for (commandline -opc)[2])'

# 3rd positional: size — common values; any positive number works.
complete -c font-set -f -n 'test (count (commandline -opc)) -eq 3' -a '10 11 12 13 13.5 14 15 16 18 20 22 24'
