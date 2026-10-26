# tui.sh - entry point of the bash-playground terminal graphics framework.
#
# Use it from a script with:
#
#     source "path/to/tui.sh"
#
# Sourcing only defines functions and variables; nothing is drawn until your
# script calls run_app. Define any of these optional hooks first:
#
#     setup()   run once, before the first frame
#     update()  advance your state (called every frame)
#     draw()    draw the frame into the virtual screen (called every frame)
#     on_key()  receives one key in $1 (letters, or UP/DOWN/LEFT/RIGHT/ENTER/SPACE)
#     cleanup() run once when the app exits for any reason
#
# Settings (environment variables or plain variables set before run_app):
#     TUI_FPS     frames per second (default 15)
#     TUI_FRAMES  stop after this many frames (default 0 = run until 'q')
#     TUI_WIDTH / TUI_HEIGHT   force a screen size instead of the terminal's
#
# While running, these globals are available to your hooks:
#     SCREEN_WIDTH SCREEN_HEIGHT   size of the virtual screen
#     TUI_FRAME                    frame counter, starting at 1

# Refuse to be executed directly: `(return 0)` only succeeds while sourcing.
if ! (return 0 2>/dev/null); then
    printf 'tui.sh is a library. Use it with:  source tui.sh\n' >&2
    exit 1
fi

if (( BASH_VERSINFO[0] < 4 )); then
    printf 'tui.sh needs Bash 4 or newer (this is %s)\n' "$BASH_VERSION" >&2
    return 1
fi

[[ -n ${_TUI_LOADED:-} ]] && return 0
_TUI_LOADED=1

# Directory containing this file, so it works no matter where you run from.
TUI_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

source "$TUI_DIR/lib/utils.sh"
source "$TUI_DIR/lib/drawing.sh"
source "$TUI_DIR/lib/renderer.sh"
source "$TUI_DIR/lib/effects/matrix.sh"
source "$TUI_DIR/lib/effects/spinner.sh"

TUI_FPS=${TUI_FPS:-15}
TUI_FRAMES=${TUI_FRAMES:-0}
TUI_FRAME=0
_TUI_RUNNING=0
_TUI_RESIZED=0
_TUI_FINISHED=0
_TUI_KEY_FD=''

# quit - ask run_app to stop after the current frame (call it from a hook).
quit() {
    _TUI_RUNNING=0
}

# Runs exactly once on the way out: user cleanup first, then the terminal.
_tui_finish() {
    if (( _TUI_FINISHED )); then return 0; fi
    _TUI_FINISHED=1
    if declare -F cleanup >/dev/null; then
        cleanup || true
    fi
    tui_restore
}

# Signal handler for Ctrl+C (INT), TERM and HUP. `exit` triggers the EXIT
# trap, which restores the terminal. 128 + signal number is the convention.
_tui_signal() {
    trap - INT TERM HUP
    exit "$1"
}

# _tui_wait_key SECONDS - wait for a key or until the timeout; sets REPLY.
# Waiting with `read -t` doubles as the frame delay, and reading a key costs
# nothing extra.
_tui_wait_key() {
    local timeout=$1 key='' rest=''
    REPLY=''
    if [[ -z $_TUI_KEY_FD ]]; then
        sleep "$timeout"
        return 0
    fi
    IFS= read -rsn1 -t "$timeout" -u "$_TUI_KEY_FD" key || return 0
    if [[ $key == $'\e' ]]; then
        # Arrow keys arrive as ESC [ A, ESC [ B, ... Read the rest quickly.
        IFS= read -rsn2 -t 0.01 -u "$_TUI_KEY_FD" rest || true
        case $rest in
            '[A') key=UP ;;   '[B') key=DOWN ;;
            '[C') key=RIGHT ;; '[D') key=LEFT ;;
            *)    key=ESC ;;
        esac
    fi
    case $key in
        '')  key=ENTER ;;      # read -n1 returns an empty string for Enter
        ' ') key=SPACE ;;
    esac
    REPLY=$key
}

# run_app - initialize the terminal and run the frame loop until 'q', Ctrl+C,
# quit, or TUI_FRAMES frames have been drawn.
run_app() {
    local has_setup=0 has_update=0 has_draw=0 has_key=0 has_resize=0
    declare -F setup     >/dev/null && has_setup=1
    declare -F update    >/dev/null && has_update=1
    declare -F draw      >/dev/null && has_draw=1
    declare -F on_key    >/dev/null && has_key=1
    declare -F on_resize >/dev/null && has_resize=1

    if ! is_uint "$TUI_FPS" || (( TUI_FPS < 1 )); then
        tui_warn "run_app: TUI_FPS must be a positive integer (got '$TUI_FPS')"
        return 2
    fi

    # Read keys from the terminal even if stdin was redirected.
    if [[ -t 0 ]]; then
        _TUI_KEY_FD=0
    elif ( : </dev/tty ) 2>/dev/null; then
        exec {_TUI_KEY_FD}</dev/tty
    else
        _TUI_KEY_FD=''
    fi

    trap '_tui_finish' EXIT
    trap '_tui_signal 130' INT
    trap '_tui_signal 143' TERM
    trap '_tui_signal 129' HUP
    trap '_TUI_RESIZED=1' WINCH

    fb_init
    tui_init
    _TUI_RUNNING=1
    TUI_FRAME=0
    if (( has_setup )); then setup; fi

    local frame_us=$(( 1000000 / TUI_FPS )) t0 wait_us timeout
    while (( _TUI_RUNNING )); do
        now_us; t0=$REPLY
        TUI_FRAME=$(( TUI_FRAME + 1 ))

        if (( _TUI_RESIZED )); then
            _TUI_RESIZED=0
            fb_init
            render_invalidate
            if (( has_resize )); then on_resize; fi
        fi

        if (( has_update )); then update; fi
        clear                       # every frame starts from a blank scene
        if (( has_draw )); then draw; fi
        render

        if (( TUI_FRAMES > 0 && TUI_FRAME >= TUI_FRAMES )); then
            break
        fi

        # Sleep for whatever is left of this frame's time budget.
        now_us
        wait_us=$(( frame_us - (REPLY - t0) ))
        if (( wait_us < 1000 )); then wait_us=1000; fi
        printf -v timeout '%d.%06d' $(( wait_us / 1000000 )) $(( wait_us % 1000000 ))
        _tui_wait_key "$timeout"
        case $REPLY in
            '')   ;;
            q|Q)  _TUI_RUNNING=0 ;;
            *)    if (( has_key )); then on_key "$REPLY"; fi ;;
        esac
    done

    _tui_finish
    trap - EXIT INT TERM HUP WINCH
}
