#!/usr/bin/env bash
# 06-process-monitor.sh - a live, top-like view of the busiest processes.
#
# Run:   ./examples/06-process-monitor.sh          (q quits, s toggles sort)
#        ./examples/06-process-monitor.sh --mock   # use data/ps-sample.txt
#
# Concepts:
#   * a pipeline as a data source    ps | sort | head
#   * mapfile                        read command output into an array
#   * refresh loops                  re-run the pipeline every N frames, not every frame
#   * process substitution           mapfile -t rows < <(pipeline)
#   * fallbacks                      use mock data if `ps` is unavailable
#   * formatting                     printf -v with %-*s padding
#
# Only reads process information; it never signals or kills anything.

set -euo pipefail
here=$(dirname -- "${BASH_SOURCE[0]}")
source "$here/../tui.sh"

mock_file="$here/../data/ps-sample.txt"
use_mock=0
case ${1:-} in
    --mock) use_mock=1 ;;
    '') ;;
    *) printf 'usage: %s [--mock]\n' "${0##*/}" >&2; exit 2 ;;
esac

# If ps does not support -eo (e.g. BusyBox or Git Bash), fall back to mock data.
if (( ! use_mock )) && ! ps -eo pid,%cpu,%mem,comm >/dev/null 2>&1; then
    use_mock=1
fi

sort_key=cpu          # cpu or mem
rows=()               # one "PID CPU MEM COMMAND" line per process
last_refresh=''

# Fill the `rows` array. Column 2 is %CPU, column 3 is %MEM. COMMAND comes
# last because it may contain spaces (read puts "the rest" in the last variable).
refresh() {
    local column=2
    [[ $sort_key == mem ]] && column=3
    if (( use_mock )); then
        # tail -n +2 skips the header line
        mapfile -t rows < <(tail -n +2 "$mock_file" | sort -k"$column","$column"nr | head -n 15)
    else
        mapfile -t rows < <(ps -eo pid,%cpu,%mem,comm --no-headers |
                            sort -k"$column","$column"nr | head -n 15)
    fi
    printf -v last_refresh '%(%H:%M:%S)T' -1     # printf can format the time itself
}

setup() {
    refresh
}

update() {
    # Running ps 15 times a second would waste CPU; once a second is plenty.
    if (( TUI_FRAME % TUI_FPS == 0 )); then
        refresh
    fi
}

on_key() {
    case $1 in
        s|S)
            if [[ $sort_key == cpu ]]; then sort_key=mem; else sort_key=cpu; fi
            refresh ;;
    esac
}

draw() {
    local w=$SCREEN_WIDTH y=4 pid cmd cpu mem bar_len color line_text source=live
    (( use_mock )) && source="mock data"

    rect 1 1 "$w" 1 blue
    text 2 1 "Process monitor  |  sorted by ${sort_key^^}  |  $source  |  $last_refresh" bright_white
    printf -v line_text '%7s  %-18s %7s %7s  %s' PID COMMAND '%CPU' '%MEM' 'CPU usage'
    text 2 3 "$line_text" bright_yellow

    if (( ${#rows[@]} == 0 )); then
        text 2 5 "No processes found." bright_red
    fi

    local row
    for row in "${rows[@]}"; do
        # `read` splits a line into variables using whitespace.
        read -r pid cpu mem cmd <<< "$row"
        printf -v line_text '%7s  %-18.18s %7s %7s' "$pid" "$cmd" "$cpu" "$mem"
        text 2 "$y" "$line_text" white

        # Bash arithmetic is integer-only: drop the decimals with ${cpu%.*}.
        bar_len=$(( ${cpu%.*} / 5 ))
        (( bar_len > 20 )) && bar_len=20
        if   (( ${cpu%.*} >= 80 )); then color=red
        elif (( ${cpu%.*} >= 20 )); then color=yellow
        else color=green
        fi
        if (( bar_len > 0 )); then
            rect 46 "$y" "$bar_len" 1 "$color"
        fi
        y=$(( y + 1 ))
        (( y >= SCREEN_HEIGHT - 1 )) && break
    done

    text 2 "$SCREEN_HEIGHT" "s: sort by CPU/MEM   q: quit" bright_black
}

run_app
