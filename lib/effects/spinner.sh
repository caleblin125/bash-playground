# lib/effects/spinner.sh - spinners that can watch background processes.
#
# Follows the effect convention (see matrix.sh): spinner_init, spinner_update,
# spinner_draw, plus spinner_add to create a spinner.
#
#     setup() {
#         spinner_init
#         sleep 3 &                         # start a background job
#         spinner_add 2 2 'Copying data' "$!"   # $! = PID of that job
#     }
#     update() { spinner_update; }
#     draw()   { spinner_draw; }
#
# A spinner with a PID spins while that process runs, then shows OK or the
# exit status. Without a PID it spins forever (until you remove it).
#
# Concepts: background jobs (&), $!, `kill -0` to test a process, `wait` to
# collect an exit status, and arrays used as a small table of records.

[[ -n ${_TUI_SPINNER_LOADED:-} ]] && return 0
_TUI_SPINNER_LOADED=1

SPINNER_X=() SPINNER_Y=() SPINNER_LABEL=() SPINNER_PID=() SPINNER_STATUS=()
SPINNER_FRAMES=()
_SPINNER_TICK=0

spinner_init() {
    SPINNER_X=() SPINNER_Y=() SPINNER_LABEL=() SPINNER_PID=() SPINNER_STATUS=()
    _SPINNER_TICK=0
    if is_utf8_locale; then
        SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    else
        SPINNER_FRAMES=('|' '/' '-' '\')
    fi
}

# spinner_add X Y LABEL [PID] -> REPLY = spinner id
spinner_add() {
    if (( $# < 3 )) || ! is_int "$1" || ! is_int "$2"; then
        tui_warn "usage: spinner_add x y label [pid]"
        return 2
    fi
    if [[ -n ${4:-} ]] && ! is_uint "$4"; then
        tui_warn "spinner_add: '$4' is not a process id"
        return 2
    fi
    local id=${#SPINNER_X[@]}
    SPINNER_X[id]=$1 SPINNER_Y[id]=$2 SPINNER_LABEL[id]=$3
    SPINNER_PID[id]=${4:-}
    SPINNER_STATUS[id]=''              # empty = still running
    REPLY=$id
}

# spinner_set_label ID LABEL
spinner_set_label() {
    SPINNER_LABEL[$1]=$2
}

# spinner_done ID - succeeds once the spinner's process has finished.
spinner_done() {
    [[ -n ${SPINNER_STATUS[$1]-} ]]
}

spinner_update() {
    local id pid status
    _SPINNER_TICK=$(( _SPINNER_TICK + 1 ))
    for id in "${!SPINNER_X[@]}"; do
        pid=${SPINNER_PID[id]}
        if [[ -z $pid || -n ${SPINNER_STATUS[id]} ]]; then
            continue
        fi
        # kill -0 sends no signal; it only checks the process still exists.
        if ! kill -0 "$pid" 2>/dev/null; then
            # wait returns the finished job's exit status.
            status=0
            wait "$pid" 2>/dev/null || status=$?
            SPINNER_STATUS[id]=$status
        fi
    done
}

spinner_draw() {
    local id frame=${SPINNER_FRAMES[(_SPINNER_TICK / 2) % ${#SPINNER_FRAMES[@]}]}
    for id in "${!SPINNER_X[@]}"; do
        case ${SPINNER_STATUS[id]} in
            '') text "${SPINNER_X[id]}" "${SPINNER_Y[id]}" "$frame" bright_cyan ;;
            0)  text "${SPINNER_X[id]}" "${SPINNER_Y[id]}" "OK" bright_green ;;
            *)  text "${SPINNER_X[id]}" "${SPINNER_Y[id]}" "!!" bright_red ;;
        esac
        local label=${SPINNER_LABEL[id]}
        case ${SPINNER_STATUS[id]} in
            ''|0) ;;
            *)    label+=" (exit ${SPINNER_STATUS[id]})" ;;
        esac
        text $(( SPINNER_X[id] + 3 )) "${SPINNER_Y[id]}" "$label" white
    done
}
