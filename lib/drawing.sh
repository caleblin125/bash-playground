# lib/drawing.sh - the virtual screen (framebuffer) and drawing primitives.
#
# Nothing in this file prints to the terminal. Drawing functions write into a
# virtual screen that describes every character cell. Each screen row is kept
# as three strings of exactly SCREEN_WIDTH characters:
#
#   _FB_CH[row]  the characters shown in the row          e.g. "  Hello   "
#   _FB_FG[row]  one color id per cell for the text       e.g. "0011111000"
#   _FB_BG[row]  one color id per cell for the background e.g. "1111111111"
#
# A color id is a single character that stands for a terminal color code
# (see _color_id). Keeping rows as strings lets Bash change a whole run of
# cells with one string operation, which is far faster than a loop in Bash.
# lib/renderer.sh later compares these rows with the previous frame and sends
# only what changed to the terminal.
#
# Coordinates are 1-based and (1, 1) is the top-left corner.
#
# Drawing rules (the same for every shape):
#   * Later drawing overwrites earlier drawing ("painter's algorithm").
#   * Anything outside the screen is silently clipped.
#   * Shapes are solid by default: cells are painted with COLOR as background.
#     Pass an optional CHAR to draw that character in COLOR instead, keeping
#     whatever background is already there.
#   * Invalid arguments print a usage message to stderr and return status 2.
#
# Concepts: functions, argument validation, substring expansion ${s:offset:len},
# arithmetic, associative arrays, and status codes.

[[ -n ${_TUI_DRAWING_LOADED:-} ]] && return 0
_TUI_DRAWING_LOADED=1

SCREEN_WIDTH=${SCREEN_WIDTH:-80}
SCREEN_HEIGHT=${SCREEN_HEIGHT:-24}
_FB_CH=() _FB_FG=() _FB_BG=()
_FB_BLANK=''                  # a row of SCREEN_WIDTH spaces

# --- Color ids ----------------------------------------------------------------
# Every distinct terminal color code gets a one-character id the first time it
# is used. The characters are chosen to be safe in Bash patterns and as keys.
_COLOR_ID_CHARS='0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ#%&+,./:;<=>?_{}~'
declare -gA _COLOR_ID=()      # SGR code -> id      e.g. [32]=2
declare -gA _COLOR_SGR=()     # id -> SGR code      e.g. [2]=32
_COLOR_NEXT=0

# _color_id SGR_CODE -> REPLY = one-character id
_color_id() {
    local code=$1
    REPLY=${_COLOR_ID[$code]-}
    if [[ -n $REPLY ]]; then return 0; fi
    if (( _COLOR_NEXT >= ${#_COLOR_ID_CHARS} )); then
        tui_warn "too many different colors; reusing the default color"
        REPLY=${_COLOR_ID[39]}
        return 0
    fi
    REPLY=${_COLOR_ID_CHARS:_COLOR_NEXT:1}
    _COLOR_NEXT=$(( _COLOR_NEXT + 1 ))
    _COLOR_ID[$code]=$REPLY
    _COLOR_SGR[$REPLY]=$code
}

# color_id NAME LAYER -> REPLY = id for a color name (see color_code in utils.sh)
color_id() {
    color_code "$1" "$2" || return 1
    _color_id "$REPLY"
}

_color_id 39; _FB_DEFAULT_FG=$REPLY    # the terminal's own text color
_color_id 49; _FB_DEFAULT_BG=$REPLY    # the terminal's own background

# --- Screen management ----------------------------------------------------------

# fb_init [WIDTH HEIGHT]
# Allocate an empty virtual screen. Without arguments the real terminal size is
# used. run_app calls this for you; tests call it with a fixed size.
fb_init() {
    if (( $# >= 2 )); then
        if ! is_uint "$1" || ! is_uint "$2" || (( $1 < 1 || $2 < 1 )); then
            tui_warn "usage: fb_init [width height]  (positive integers)"
            return 2
        fi
        SCREEN_WIDTH=$1
        SCREEN_HEIGHT=$2
    else
        screen_size
    fi
    printf -v _FB_BLANK '%*s' "$SCREEN_WIDTH" ''
    clear
}

# _repeat CHAR COUNT -> REPLY  (internal and fast: no validation)
_repeat() {
    printf -v REPLY '%*s' "$2" ''
    REPLY=${REPLY// /"$1"}
}

# clear [COLOR]
# Reset every cell to a space with the given background (default: terminal's).
# Note: inside scripts that source tui.sh, `clear` means this function. Use
# `command clear` if you ever need the real clear(1) program.
clear() {
    local bg=$_FB_DEFAULT_BG fg_row bg_row y
    if (( $# >= 1 )); then
        if ! color_id "$1" bg; then
            tui_warn "clear: unknown color '$1'"
            return 2
        fi
        bg=$REPLY
    fi
    _repeat "$_FB_DEFAULT_FG" "$SCREEN_WIDTH"; fg_row=$REPLY
    _repeat "$bg" "$SCREEN_WIDTH";             bg_row=$REPLY
    for (( y = 0; y < SCREEN_HEIGHT; y++ )); do
        _FB_CH[y]=$_FB_BLANK
        _FB_FG[y]=$fg_row
        _FB_BG[y]=$bg_row
    done
}

# _fb_span X1 X2 Y CHARS FG_ID BG_ID
# Internal workhorse: overwrite cells X1..X2 (inclusive, 1-based) of row Y.
# CHARS holds either X2-X1+1 characters or a single character to repeat.
# An empty FG_ID or BG_ID leaves that color unchanged. Clips to the screen.
_fb_span() {
    local x1=$1 x2=$2 y=$3 chars=$4 fg=$5 bg=$6 n row
    if (( y < 1 || y > SCREEN_HEIGHT || x2 < 1 || x1 > SCREEN_WIDTH || x2 < x1 )); then
        return 0
    fi
    if (( ${#chars} == 1 )); then
        _repeat "$chars" $(( x2 - x1 + 1 )); chars=$REPLY
    fi
    if (( x1 < 1 )); then                     # clip on the left
        chars=${chars:1-x1}
        x1=1
    fi
    if (( x2 > SCREEN_WIDTH )); then          # clip on the right
        x2=$SCREEN_WIDTH
    fi
    n=$(( x2 - x1 + 1 ))
    chars=${chars:0:n}
    row=$(( y - 1 ))
    # Splice: keep the part before x1, insert the new cells, keep the rest.
    _FB_CH[row]=${_FB_CH[row]:0:x1-1}$chars${_FB_CH[row]:x2}
    if [[ -n $fg ]]; then
        _repeat "$fg" "$n"
        _FB_FG[row]=${_FB_FG[row]:0:x1-1}$REPLY${_FB_FG[row]:x2}
    fi
    if [[ -n $bg ]]; then
        _repeat "$bg" "$n"
        _FB_BG[row]=${_FB_BG[row]:0:x1-1}$REPLY${_FB_BG[row]:x2}
    fi
}

# _fb_put X Y CHAR FG_ID BG_ID - write one cell (internal, no validation).
_fb_put() {
    if (( $1 < 1 || $1 > SCREEN_WIDTH || $2 < 1 || $2 > SCREEN_HEIGHT )); then
        return 0
    fi
    local x=$1 row=$(( $2 - 1 ))
    _FB_CH[row]=${_FB_CH[row]:0:x-1}$3${_FB_CH[row]:x}
    if [[ -n $4 ]]; then _FB_FG[row]=${_FB_FG[row]:0:x-1}$4${_FB_FG[row]:x}; fi
    if [[ -n $5 ]]; then _FB_BG[row]=${_FB_BG[row]:0:x-1}$5${_FB_BG[row]:x}; fi
}

# _check_ints FUNCTION_NAME USAGE VALUE...
# Fail with a usage message unless every VALUE is an integer. Validating before
# arithmetic matters: Bash evaluates text inside $(( )) as code.
_check_ints() {
    local fn=$1 usage=$2 value
    shift 2
    for value in "$@"; do
        if ! is_int "$value"; then
            tui_warn "$fn: '$value' is not an integer"
            tui_warn "usage: $usage"
            return 2
        fi
    done
}

# _paint FUNCTION_NAME COLOR [CHAR]
# Decide how a shape's cells look. Sets _P_CH, _P_FG and _P_BG.
_paint() {
    local fn=$1 color=$2
    if (( $# >= 3 )) && [[ -n $3 ]]; then
        color_id "$color" fg || { tui_warn "$fn: unknown color '$color'"; return 2; }
        _P_CH=${3:0:1} _P_FG=$REPLY _P_BG=''
    else
        color_id "$color" bg || { tui_warn "$fn: unknown color '$color'"; return 2; }
        _P_CH=' ' _P_FG=$_FB_DEFAULT_FG _P_BG=$REPLY
    fi
}

# fb_cell X Y -> sets CELL_CH, CELL_FG, CELL_BG (colors as SGR codes such as 32)
# Returns 1 if (X, Y) is off screen. Handy for tests and debugging.
fb_cell() {
    CELL_CH='' CELL_FG='' CELL_BG=''
    if (( $1 < 1 || $1 > SCREEN_WIDTH || $2 < 1 || $2 > SCREEN_HEIGHT )); then
        return 1
    fi
    local x=$(( $1 - 1 )) row=$(( $2 - 1 ))
    CELL_CH=${_FB_CH[row]:x:1}
    CELL_FG=${_COLOR_SGR[${_FB_FG[row]:x:1}]}
    CELL_BG=${_COLOR_SGR[${_FB_BG[row]:x:1}]}
}

# fb_dump - print the virtual screen as plain text (characters only).
# Try:  source tui.sh; fb_init 20 5; rect 2 2 4 2 red '#'; fb_dump
fb_dump() {
    printf '%s\n' "${_FB_CH[@]}"
}

# --- Public drawing API -------------------------------------------------------

# text X Y STRING [COLOR [BACKGROUND]]
# Draw a single line of text (default color: the terminal's text color).
# Without BACKGROUND the existing background is kept, so text can sit on top
# of a filled rectangle.
text() {
    local usage='text x y string [color [background]]'
    if (( $# < 3 )); then tui_warn "usage: $usage"; return 2; fi
    _check_ints text "$usage" "$1" "$2" || return 2
    local x=$1 y=$2 s=$3 fg=$_FB_DEFAULT_FG bg=''
    if (( $# >= 4 )); then
        color_id "$4" fg || { tui_warn "text: unknown color '$4'"; return 2; }
        fg=$REPLY
    fi
    if (( $# >= 5 )); then
        color_id "$5" bg || { tui_warn "text: unknown color '$5'"; return 2; }
        bg=$REPLY
    fi
    s=${s//[[:cntrl:]]/ }      # tabs, newlines and escapes would corrupt the screen
    if [[ -z $s ]]; then return 0; fi
    if (( ${#s} == 1 )); then
        _fb_put "$x" "$y" "$s" "$fg" "$bg"
    else
        _fb_span "$x" $(( x + ${#s} - 1 )) "$y" "$s" "$fg" "$bg"
    fi
}

# rect X Y WIDTH HEIGHT COLOR [CHAR]
# Filled rectangle whose top-left corner is (X, Y).
rect() {
    local usage='rect x y width height color [char]'
    if (( $# < 5 )); then tui_warn "usage: $usage"; return 2; fi
    _check_ints rect "$usage" "$1" "$2" "$3" "$4" || return 2
    if (( $3 < 0 || $4 < 0 )); then
        tui_warn "rect: width and height must not be negative"
        return 2
    fi
    _paint rect "$5" "${6:-}" || return 2

    local x=$1 y y1=$(( $2 + $4 - 1 ))
    for (( y = $2; y <= y1; y++ )); do
        _fb_span "$x" $(( x + $3 - 1 )) "$y" "$_P_CH" "$_P_FG" "$_P_BG"
    done
}

# line X1 Y1 X2 Y2 COLOR [CHAR]
# Straight line using Bresenham's algorithm (integer arithmetic only).
line() {
    local usage='line x1 y1 x2 y2 color [char]'
    if (( $# < 5 )); then tui_warn "usage: $usage"; return 2; fi
    _check_ints line "$usage" "$1" "$2" "$3" "$4" || return 2
    _paint line "$5" "${6:-}" || return 2

    local x=$1 y=$2 x2=$3 y2=$4
    local dx=$(( x2 > x ? x2 - x : x - x2 )) sx=$(( x < x2 ? 1 : -1 ))
    local dy=$(( y2 > y ? y - y2 : y2 - y )) sy=$(( y < y2 ? 1 : -1 ))
    local err=$(( dx + dy )) e2
    while true; do
        _fb_put "$x" "$y" "$_P_CH" "$_P_FG" "$_P_BG"
        if (( x == x2 && y == y2 )); then break; fi
        e2=$(( 2 * err ))
        if (( e2 >= dy )); then err=$(( err + dy )); x=$(( x + sx )); fi
        if (( e2 <= dx )); then err=$(( err + dx )); y=$(( y + sy )); fi
    done
}

# circle CENTER_X CENTER_Y RADIUS COLOR [CHAR]
# Filled circle. Terminal cells are about twice as tall as they are wide, so
# the circle is stretched horizontally (2 columns per row) to look round.
circle() {
    local usage='circle center_x center_y radius color [char]'
    if (( $# < 4 )); then tui_warn "usage: $usage"; return 2; fi
    _check_ints circle "$usage" "$1" "$2" "$3" || return 2
    if (( $3 < 0 )); then
        tui_warn "circle: radius must not be negative"
        return 2
    fi
    _paint circle "$4" "${5:-}" || return 2

    # A cell (dx, dy) is inside when (dx/2)^2 + dy^2 <= r^2 + r. Multiply by 4
    # to stay in integers, then find the half-width of each row.
    local cx=$1 cy=$2 r=$3 dy half rest limit=$(( 4 * $3 * $3 + 4 * $3 ))
    for (( dy = -r; dy <= r; dy++ )); do
        rest=$(( limit - 4 * dy * dy ))
        half=$(( 2 * r ))
        while (( half * half > rest )); do half=$(( half - 1 )); done
        _fb_span $(( cx - half )) $(( cx + half )) $(( cy + dy )) "$_P_CH" "$_P_FG" "$_P_BG"
    done
}
