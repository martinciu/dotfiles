# qmk_hid — RAW HID / VIA CLI for QMK keyboards
# Upstream: https://github.com/FrameworkComputer/qmk_hid (v0.1.13)

set -l subcommands factory via qmk help
set -l no_subcmd "not __fish_seen_subcommand_from $subcommands"

# --- global options
complete -c qmk_hid -n "$no_subcmd" -s l -l list    -d "List connected HID devices"
complete -c qmk_hid -n "$no_subcmd" -s V -l version -d "Print version"
complete -c qmk_hid -s v -l verbose -d "Verbose output"
complete -c qmk_hid -s h -l help    -d "Print help"
complete -c qmk_hid       -l vid    -d "Vendor ID (hex)"  -x
complete -c qmk_hid       -l pid    -d "Product ID (hex)" -x

# --- subcommands
complete -c qmk_hid -n "$no_subcmd" -f -a factory -d "Factory utilities (Framework 16)"
complete -c qmk_hid -n "$no_subcmd" -f -a via     -d "VIA runtime control (RGB / backlight / EEPROM)"
complete -c qmk_hid -n "$no_subcmd" -f -a qmk     -d "QMK protocol passthrough"
complete -c qmk_hid -n "$no_subcmd" -f -a help    -d "Print help for a subcommand"

# `help <subcmd>`
complete -c qmk_hid -n "__fish_seen_subcommand_from help" -f -a "factory via qmk"

# --- via
complete -c qmk_hid -n "__fish_seen_subcommand_from via" -l info               -d "VIA protocol/config dump (debug only)"
complete -c qmk_hid -n "__fish_seen_subcommand_from via" -l device-indication  -d "Flash backlight 3× (identify device)"
complete -c qmk_hid -n "__fish_seen_subcommand_from via" -l rgb-brightness     -d "Set/get RGB brightness % (0–100)" -x
complete -c qmk_hid -n "__fish_seen_subcommand_from via" -l rgb-effect         -d "Set/get RGB effect index"          -x
complete -c qmk_hid -n "__fish_seen_subcommand_from via" -l rgb-effect-speed   -d "Set/get RGB effect speed (0–255)"  -x
complete -c qmk_hid -n "__fish_seen_subcommand_from via" -l rgb-hue            -d "Set/get RGB hue (0–255)"           -x
complete -c qmk_hid -n "__fish_seen_subcommand_from via" -l rgb-saturation     -d "Set/get RGB saturation (0–255)"    -x
complete -c qmk_hid -n "__fish_seen_subcommand_from via" -l rgb-color          -d "Set RGB color (named)" \
    -x -a "red yellow green cyan blue purple white"
complete -c qmk_hid -n "__fish_seen_subcommand_from via" -l backlight          -d "Set/get backlight %" -x
complete -c qmk_hid -n "__fish_seen_subcommand_from via" -l backlight-breathing -d "Set/get backlight breathing" \
    -x -a "true false"
complete -c qmk_hid -n "__fish_seen_subcommand_from via" -l save               -d "Persist current settings to EEPROM"
complete -c qmk_hid -n "__fish_seen_subcommand_from via" -l eeprom-reset       -d "Reset EEPROM (firmware-dependent)"
complete -c qmk_hid -n "__fish_seen_subcommand_from via" -l bootloader         -d "Jump to bootloader (firmware-dependent)"

# --- qmk
complete -c qmk_hid -n "__fish_seen_subcommand_from qmk" -s c -l console -d "Listen to QMK debug console"

# --- factory
complete -c qmk_hid -n "__fish_seen_subcommand_from factory" -l led          -d "Light up a single LED" -x
complete -c qmk_hid -n "__fish_seen_subcommand_from factory" -s s            -d "(Boolean flag; see qmk_hid help factory)"
complete -c qmk_hid -n "__fish_seen_subcommand_from factory" -l bios-mode    -d "Toggle BIOS mode"     -x -a "true false"
complete -c qmk_hid -n "__fish_seen_subcommand_from factory" -l factory-mode -d "Toggle factory mode" -x -a "true false"
