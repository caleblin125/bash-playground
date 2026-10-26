#!/usr/bin/env bash
# 02-progress.sh - an animated progress bar that redraws in place.
#
# Run:   ./examples/02-progress.sh
#        ./examples/02-progress.sh 40 0.05      # bar width, delay per step
#
# Concepts:
#   * C-style for loops              for ((i = 0; i <= 100; i++))
#   * arithmetic expansion           $(( done * width / 100 ))
#   * carriage return                \r moves the cursor to the start of the line
#   * cursor control                 \e[?25l hides the cursor, \e[?25h shows it
#   * trap                           restore the cursor even after Ctrl+C
#   * argument validation            [[ $width =~ ^[0-9]+$ ]]
#   * sleep                          pause between frames

set -euo pipefail

width=${1:-30}
delay=${2:-0.03}

# Validate before using a value in arithmetic: $(( )) would treat other text
# as a variable name or expression.
if ! [[ $width =~ ^[0-9]+$ ]] || (( width < 5 )); then
    printf 'usage: %s [bar_width>=5] [delay_seconds]\n' "$0" >&2
    exit 2
fi
if ! [[ $delay =~ ^[0-9]*\.?[0-9]+$ ]]; then
    printf '%s: delay must be a number like 0.05\n' "$0" >&2
    exit 2
fi

# `trap CMD EXIT` runs CMD whenever the script exits, normally or not.
# Ctrl+C sends SIGINT; exiting from its trap also triggers the EXIT trap.
trap 'printf "\e[?25h\e[0m"' EXIT
trap 'printf "\nInterrupted\n" >&2; exit 130' INT
printf '\e[?25l'                     # hide the cursor while animating

tasks=("Loading modules" "Staging input" "Running solver" "Writing output")

for task in "${tasks[@]}"; do
    for (( pct = 0; pct <= 100; pct += 2 )); do
        filled=$(( pct * width / 100 ))
        empty=$(( width - filled ))

        # printf -v stores the result in a variable instead of printing it.
        printf -v bar_on  '%*s' "$filled" ''
        printf -v bar_off '%*s' "$empty" ''
        bar_on=${bar_on// /#}
        bar_off=${bar_off// /.}

        # \r returns to column 1 so the next printf overwrites this line.
        # \e[K erases anything left over to the right.
        printf '\r\e[36m%-16s\e[0m [\e[32m%s\e[2m%s\e[0m] %3d%%\e[K' \
            "$task" "$bar_on" "$bar_off" "$pct"
        sleep "$delay"
    done
    printf '\n'                      # keep the finished bar, start a new line
done

printf '\e[1;32mAll steps complete.\e[0m\n'
