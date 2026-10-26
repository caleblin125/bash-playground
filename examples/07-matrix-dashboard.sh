#!/usr/bin/env bash
# 07-matrix-dashboard.sh - Matrix rain behind a mock HPC node status panel.
#
# Run:   ./examples/07-matrix-dashboard.sh        (q quits, p pauses the rain)
#        MATRIX_COLOR=cyan ./examples/07-matrix-dashboard.sh
#
# Concepts:
#   * reusable effects               matrix_init / matrix_update / matrix_draw
#   * layering by drawing order      rain first, panel on top
#   * arrays                         parallel arrays describe each node
#   * reading a file into arrays     while read ...; done < data/nodes.txt
#   * custom drawing helpers         panel() and meter() built from primitives
#   * background jobs and cleanup    sleep & / $! / spinner / kill in cleanup

set -euo pipefail
here=$(dirname -- "${BASH_SOURCE[0]}")
source "$here/../tui.sh"

node_file="$here/../data/nodes.txt"
if [[ ! -r $node_file ]]; then
    printf 'cannot read %s\n' "$node_file" >&2
    exit 2
fi

# Parallel arrays: index i describes the same node in every array.
names=() states=() loads=() mem_used=() mem_total=()
while read -r name state load _cores used total; do
    [[ -z $name || $name == \#* ]] && continue          # skip blanks and comments
    names+=("$name") states+=("$state") loads+=("$load")
    mem_used+=("$used") mem_total+=("$total")
done < "$node_file"

paused=0
sync_pid=''

# panel X Y WIDTH HEIGHT TITLE - a framed box with a title bar.
panel() {
    local x=$1 y=$2 w=$3 h=$4 title=$5
    rect "$x" "$y" "$w" "$h" black                           # body hides the rain
    rect "$x" "$y" "$w" 1 green                              # title bar
    text $(( x + 2 )) "$y" "$title" black
    line "$x" $(( y + h - 1 )) $(( x + w - 1 )) $(( y + h - 1 )) green '-'
}

# meter X Y WIDTH PERCENT - a horizontal bar colored by how full it is.
meter() {
    local x=$1 y=$2 w=$3 pct=$4 color=green fill
    (( pct > 100 )) && pct=100
    fill=$(( pct * w / 100 ))
    if   (( pct >= 90 )); then color=red
    elif (( pct >= 60 )); then color=yellow
    fi
    rect "$x" "$y" "$w" 1 bright_black '.'
    if (( fill > 0 )); then rect "$x" "$y" "$fill" 1 "$color"; fi
}

state_color() {
    case $1 in
        RUNNING)  REPLY=bright_green ;;
        IDLE)     REPLY=bright_cyan ;;
        DRAINING) REPLY=bright_yellow ;;
        *)        REPLY=bright_red ;;
    esac
}

setup() {
    matrix_init
    spinner_init
    # Start a pretend data transfer in the background. $! is its process ID.
    sleep $(( 3 + RANDOM % 4 )) &
    sync_pid=$!
    spinner_add 0 0 "Syncing /scratch" "$sync_pid"
    spinner_add 0 0 "Polling scheduler"
}

update() {
    if (( ! paused )); then matrix_update; fi
    spinner_update

    # Every second, let the load of running nodes drift up or down a little.
    if (( TUI_FRAME % TUI_FPS == 0 )); then
        local i
        for i in "${!names[@]}"; do
            if [[ ${states[i]} == RUNNING ]]; then
                random_int -8 8
                clamp $(( loads[i] + REPLY )) 5 100
                loads[i]=$REPLY
            fi
        done
    fi
}

on_key() {
    case $1 in
        p|P) paused=$(( ! paused )) ;;
    esac
}

on_resize() {
    matrix_init          # the number of rain columns depends on the width
}

draw() {
    clear black
    matrix_draw                                   # 1. background layer

    local n=${#names[@]} w=58
    local h=$(( n + 7 ))
    local x=$(( (SCREEN_WIDTH - w) / 2 + 1 )) y=$(( (SCREEN_HEIGHT - h) / 2 + 1 ))
    (( x < 1 )) && x=1
    (( y < 1 )) && y=1

    local now buf
    printf -v now '%(%H:%M:%S)T' -1     # -v stores the result: no subshell needed
    panel "$x" "$y" "$w" "$h" " CLUSTER STATUS  $now "      # 2. foreground layer
    text $(( x + 2 )) $(( y + 2 )) "NODE     STATE      CPU LOAD             MEMORY" bright_white

    local i row color running=0
    for i in "${!names[@]}"; do
        row=$(( y + 3 + i ))
        # Copy REPLY right away: the next framework call overwrites it.
        state_color "${states[i]}"; color=$REPLY
        text $(( x + 2 ))  "$row" "${names[i]}" white
        text $(( x + 11 )) "$row" "${states[i]}" "$color"
        meter $(( x + 22 )) "$row" 12 "${loads[i]}"
        printf -v buf '%3d%%   %3d/%dG' "${loads[i]}" "${mem_used[i]}" "${mem_total[i]}"
        text $(( x + 35 )) "$row" "$buf" white
        [[ ${states[i]} == RUNNING ]] && running=$(( running + 1 ))
    done

    # Place the spinners inside the panel now that we know where it is.
    SPINNER_X[0]=$(( x + 2 )) SPINNER_Y[0]=$(( y + h - 3 ))
    SPINNER_X[1]=$(( x + 30 )) SPINNER_Y[1]=$(( y + h - 3 ))
    spinner_draw

    text $(( x + 2 )) $(( y + h - 1 )) " $running/$n running   p: pause rain   q: quit " bright_green black
}

cleanup() {
    # Only kill the process this script started, and only if it still runs.
    if [[ -n $sync_pid ]] && kill -0 "$sync_pid" 2>/dev/null; then
        kill "$sync_pid" 2>/dev/null || true
    fi
}

run_app
