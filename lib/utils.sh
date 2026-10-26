# lib/utils.sh - small helpers shared by the framework, the examples, and the tests.
#
# This file only defines functions and variables; sourcing it never prints or
# starts anything. Functions that produce a value store it in the global
# variable REPLY (the same convention the `read` builtin uses) so callers can
# avoid the cost of a $(...) subshell in tight animation loops.
#
# Concepts: functions, `local`, `return` status codes, [[ ... ]] tests, regular
# expressions, associative arrays, arithmetic expansion, stderr (>&2).

[[ -n ${_TUI_UTILS_LOADED:-} ]] && return 0
_TUI_UTILS_LOADED=1

# Print a message to standard error. Diagnostics go to stderr so stdout stays
# clean for data that another program might read through a pipe.
tui_warn() {
    printf '%s\n' "$*" >&2
}

# Succeeds (status 0) when $1 is an integer such as 7, -3, or 0.
is_int() {
    [[ ${1-} =~ ^-?[0-9]+$ ]]
}

# Succeeds when $1 is a non-negative integer.
is_uint() {
    [[ ${1-} =~ ^[0-9]+$ ]]
}

# clamp VALUE MIN MAX -> REPLY
clamp() {
    local value=$1 min=$2 max=$3
    if (( value < min )); then
        value=$min
    elif (( value > max )); then
        value=$max
    fi
    REPLY=$value
}

# random_int MIN MAX -> REPLY (inclusive range, uses Bash's $RANDOM: 0..32767)
random_int() {
    local min=$1 max=$2
    REPLY=$(( min + RANDOM % (max - min + 1) ))
}

# repeat_char CHAR COUNT -> REPLY
# Example: repeat_char '#' 5; printf '%s\n' "$REPLY"   # prints #####
repeat_char() {
    local char=$1 count=$2 out=''
    if (( count > 0 )); then
        printf -v out '%*s' "$count" ''   # COUNT spaces...
        out=${out// /"$char"}             # ...then replace each space with CHAR
    fi
    REPLY=$out
}

# now_us -> REPLY (current time in microseconds, or 0 if the clock is unavailable)
# EPOCHREALTIME exists in Bash 5+. Some locales use a comma as the decimal point.
now_us() {
    if [[ -n ${EPOCHREALTIME:-} ]]; then
        REPLY=${EPOCHREALTIME//[.,]/}
    else
        REPLY=0
    fi
}

# Succeeds when the current locale can display UTF-8 characters.
is_utf8_locale() {
    local loc=${LC_ALL:-${LC_CTYPE:-${LANG:-}}}
    [[ $loc == *[Uu][Tt][Ff]-8* || $loc == *[Uu][Tt][Ff]8* ]]
}

# --- Colors ------------------------------------------------------------------
# Terminals understand "SGR" escape sequences such as ESC[31m (red text).
# Foreground codes are 30-37, background codes are 40-47; bright variants add 60.

declare -gA _TUI_COLOR_INDEX=(
    [black]=0 [red]=1 [green]=2 [yellow]=3 [blue]=4 [magenta]=5 [cyan]=6 [white]=7
)

# color_code NAME LAYER -> REPLY
#   NAME : black red green yellow blue magenta cyan white, bright_<name>,
#          gray/grey, default, or a number 0-255 for 256-color terminals.
#   LAYER: fg (text color) or bg (cell background).
# Returns status 1 (and leaves REPLY empty) for an unknown color.
color_code() {
    local name=${1-} layer=${2:-fg} base=30 bright=0
    REPLY=''
    [[ $layer == bg ]] && base=40

    if [[ $name =~ ^[0-9]+$ ]]; then
        if (( name > 255 )); then
            return 1
        fi
        # 38;5;N / 48;5;N selects color N from the 256-color palette.
        REPLY="$(( base + 8 ));5;$name"
        return 0
    fi

    case $name in
        default | '') REPLY=$(( base + 9 )); return 0 ;;
        gray | grey)  name=bright_black ;;
    esac
    if [[ $name == bright_* ]]; then
        bright=60
        name=${name#bright_}
    fi
    if [[ -z ${_TUI_COLOR_INDEX[$name]+set} ]]; then
        return 1
    fi
    REPLY=$(( base + bright + _TUI_COLOR_INDEX[$name] ))
}

# --- Screen size ---------------------------------------------------------------

# screen_size -> sets SCREEN_WIDTH and SCREEN_HEIGHT
# Order of preference: TUI_WIDTH/TUI_HEIGHT environment overrides (useful for
# tests), `stty size` on the terminal, `tput`, then a safe 80x24 default.
screen_size() {
    local rows='' cols='' size
    if size=$(stty size 2>/dev/null </dev/tty); then
        read -r rows cols <<< "$size"
    fi
    if ! is_uint "$cols" || (( cols == 0 )); then
        cols=$(tput cols 2>/dev/null) || cols=''
        rows=$(tput lines 2>/dev/null) || rows=''
    fi
    is_uint "$cols" && (( cols > 0 )) || cols=80
    is_uint "$rows" && (( rows > 0 )) || rows=24

    SCREEN_WIDTH=${TUI_WIDTH:-$cols}
    SCREEN_HEIGHT=${TUI_HEIGHT:-$rows}
}
