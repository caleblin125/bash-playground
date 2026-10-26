# lib/renderer.sh - turn the virtual screen into terminal output.
#
# Terminals are controlled by "escape sequences": bytes that start with the
# ESC character (written $'\e' in Bash) and are interpreted instead of printed.
#
#   ESC[<row>;<col>H   move the cursor          ESC[2J      clear the screen
#   ESC[31;44m         red text, blue bg        ESC[0m      reset colors
#   ESC[?25l / ?25h    hide / show cursor       ESC[?1049h  alternate screen
#
# Differential rendering: `render` compares each row of the current frame with
# the row it drew last time. Unchanged rows cost one string comparison. For a
# changed row it finds the first and last changed cell and sends only that
# span, switching colors only where they change. All output for a frame is
# collected in one string and written with a single printf. Clearing and
# repainting the whole terminal every frame is what causes flicker; this
# avoids it.
#
# Concepts: escape sequences, printf, string building, substring expansion,
# pattern removal ${var%%pattern}, stty, and saving/restoring terminal state.

[[ -n ${_TUI_RENDERER_LOADED:-} ]] && return 0
_TUI_RENDERER_LOADED=1

_PREV_CH=() _PREV_FG=() _PREV_BG=()   # rows of the last frame actually drawn
_RENDER_FULL=1                         # 1 = clear terminal and redraw everything
TUI_FRAME_OUT=''                       # escape sequences for the latest frame

# --- Direct terminal helpers --------------------------------------------------
# These print immediately. They are for simple scripts (see examples 01 and 02)
# that do not use the virtual screen. Inside run_app, draw with text/rect/...

# set_color FOREGROUND [BACKGROUND]
set_color() {
    local fg
    color_code "${1-}" fg || { tui_warn "set_color: unknown color '${1-}'"; return 2; }
    fg=$REPLY
    if (( $# >= 2 )); then
        color_code "$2" bg || { tui_warn "set_color: unknown color '$2'"; return 2; }
        printf '\e[%s;%sm' "$fg" "$REPLY"
    else
        printf '\e[%sm' "$fg"
    fi
}

reset_color() { printf '\e[0m'; }
hide_cursor() { printf '\e[?25l'; }
show_cursor() { printf '\e[?25h'; }

# move_cursor X Y  (1-based, X = column, Y = row)
move_cursor() {
    if ! is_uint "${1-}" || ! is_uint "${2-}"; then
        tui_warn "usage: move_cursor x y"
        return 2
    fi
    printf '\e[%d;%dH' "$2" "$1"
}

# --- Terminal setup and restore --------------------------------------------------

_TUI_STTY_SAVED=''
_TUI_ACTIVE=0

# tui_init - switch to the alternate screen, hide the cursor, stop key echo.
tui_init() {
    if [[ -t 0 ]]; then
        _TUI_STTY_SAVED=$(stty -g 2>/dev/null) || _TUI_STTY_SAVED=''
        stty -echo -icanon 2>/dev/null || true
    fi
    # alternate screen, hide cursor, disable line wrap, reset colors, clear
    printf '\e[?1049h\e[?25l\e[?7l\e[0m\e[2J'
    _TUI_ACTIVE=1
    render_invalidate
}

# tui_restore - undo tui_init. Safe to call more than once.
tui_restore() {
    if (( ! _TUI_ACTIVE )); then return 0; fi
    _TUI_ACTIVE=0
    printf '\e[0m\e[?7h\e[?25h\e[?1049l'
    if [[ -n $_TUI_STTY_SAVED ]]; then
        stty "$_TUI_STTY_SAVED" 2>/dev/null || true
    fi
}

# --- Differential renderer ----------------------------------------------------------

# render_invalidate - forget the previous frame so the next render repaints
# everything (used at startup and after the terminal is resized).
render_invalidate() {
    _PREV_CH=() _PREV_FG=() _PREV_BG=()
    _RENDER_FULL=1
}

# _common_prefix A B -> REPLY = number of leading characters A and B share.
# Binary search: each step compares two substrings inside Bash itself.
_common_prefix() {
    local lo=0 hi=${#1} mid
    (( ${#2} < hi )) && hi=${#2}
    while (( lo < hi )); do
        mid=$(( (lo + hi + 1) / 2 ))
        if [[ ${1:0:mid} == "${2:0:mid}" ]]; then lo=$mid; else hi=$(( mid - 1 )); fi
    done
    REPLY=$lo
}

# _common_suffix A B -> REPLY = number of trailing characters they share.
_common_suffix() {
    local lo=0 hi=${#1} mid
    (( ${#2} < hi )) && hi=${#2}
    while (( lo < hi )); do
        mid=$(( (lo + hi + 1) / 2 ))
        if [[ ${1: -mid} == "${2: -mid}" ]]; then lo=$mid; else hi=$(( mid - 1 )); fi
    done
    REPLY=$lo
}

# _widen_span NEW OLD - grow the caller's `first`/`last` (0-based cell
# positions) to cover every cell where the two row strings differ.
# Bash functions can see the local variables of the function that called them.
_widen_span() {
    if [[ $1 == "$2" ]]; then return 0; fi
    _common_prefix "$1" "$2"
    if (( REPLY < first )); then first=$REPLY; fi
    _common_suffix "$1" "$2"
    if (( ${#1} - 1 - REPLY > last )); then last=$(( ${#1} - 1 - REPLY )); fi
}

# _render_build - compute TUI_FRAME_OUT for the current frame and remember the
# frame as "previous". Separate from `render` so tests can inspect the output.
_render_build() {
    local w=$SCREEN_WIDTH h=$SCREEN_HEIGHT out='' cur='' y
    local ch fg bg first last p n n2 run f b sgr

    if (( _RENDER_FULL )); then
        out=$'\e[0m\e[2J'
        _RENDER_FULL=0
    fi

    for (( y = 0; y < h; y++ )); do
        ch=${_FB_CH[y]} fg=${_FB_FG[y]} bg=${_FB_BG[y]}
        if [[ $ch == "${_PREV_CH[y]-}" && $fg == "${_PREV_FG[y]-}" && $bg == "${_PREV_BG[y]-}" ]]; then
            continue                                   # row unchanged: send nothing
        fi

        # Find the changed span [first, last] (0-based) across all three strings.
        if [[ -z ${_PREV_CH[y]-} ]]; then
            first=0 last=$(( w - 1 ))
        else
            first=$w last=-1
            _widen_span "$ch" "${_PREV_CH[y]}"
            _widen_span "$fg" "${_PREV_FG[y]}"
            _widen_span "$bg" "${_PREV_BG[y]}"
        fi
        _PREV_CH[y]=$ch _PREV_FG[y]=$fg _PREV_BG[y]=$bg
        if (( last < first )); then continue; fi

        out+=$'\e['"$(( y + 1 ));$(( first + 1 ))H"   # jump to the start of the span

        # Emit the span as runs of cells that share the same colors.
        p=$first
        while (( p <= last )); do
            f=${fg:p:1} b=${bg:p:1}
            # Length of the run of '$f' starting at p: delete everything from
            # the first character that is not '$f' (%% = longest match).
            run=${fg:p:last-p+1};  run=${run%%[!"$f"]*}; n=${#run}
            run=${bg:p:n};         run=${run%%[!"$b"]*}; n2=${#run}
            (( n2 < n )) && n=$n2
            sgr="${_COLOR_SGR[$f]};${_COLOR_SGR[$b]}"
            if [[ $sgr != "$cur" ]]; then
                out+=$'\e[0;'"${sgr}m"                  # change color only when needed
                cur=$sgr
            fi
            out+=${ch:p:n}
            p=$(( p + n ))
        done
    done

    if [[ -n $out ]]; then out+=$'\e[0m'; fi
    TUI_FRAME_OUT=$out
}

# render - draw the virtual screen on the terminal (changed cells only).
render() {
    _render_build
    if [[ -n $TUI_FRAME_OUT ]]; then
        printf '%s' "$TUI_FRAME_OUT"
    fi
}
