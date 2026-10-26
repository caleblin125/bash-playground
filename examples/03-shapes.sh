#!/usr/bin/env bash
# 03-shapes.sh - rectangles, lines, circles and text with the graphics API.
#
# Run:   ./examples/03-shapes.sh          (press q to quit)
#
# Concepts:
#   * sourcing a library             source "$here/../tui.sh"
#   * defining functions             draw_house() { ...; }
#   * positional parameters          $1 $2 ... $#
#   * local variables                local x=$1
#   * argument validation            return 2 with a message on stderr
#   * drawing order                  later shapes cover earlier ones
#
# The API (all coordinates are 1-based columns/rows, (1,1) = top-left):
#   rect x y width height color [char]
#   line x1 y1 x2 y2 color [char]
#   circle center_x center_y radius color [char]
#   text x y string [color [background]]
#   clear [color]

set -euo pipefail

# Find tui.sh relative to this script, wherever it is run from.
here=$(dirname -- "${BASH_SOURCE[0]}")
source "$here/../tui.sh"

# draw_house X Y WIDTH COLOR - a custom helper built from primitives.
# Bash functions take arguments positionally, like a small script.
draw_house() {
    if (( $# != 4 )); then
        printf 'usage: draw_house x y width color (got %d args)\n' "$#" >&2
        return 2
    fi
    local x=$1 y=$2 width=$3 color=$4     # `local` keeps these out of global scope
    if ! is_int "$x" || ! is_int "$y" || ! is_uint "$width" || (( width < 6 )); then
        printf 'draw_house: bad geometry x=%s y=%s width=%s\n' "$x" "$y" "$width" >&2
        return 2
    fi

    local half=$(( width / 2 )) height=$(( width / 3 ))
    rect "$x" "$y" "$width" "$height" "$color"                    # walls
    line "$x" "$(( y - 1 ))" "$(( x + half ))" "$(( y - half / 2 - 1 ))" red '/'
    line "$(( x + half ))" "$(( y - half / 2 - 1 ))" "$(( x + width - 1 ))" "$(( y - 1 ))" red '\'
    rect "$(( x + half - 1 ))" "$(( y + height - 2 ))" 2 2 yellow    # door
}

draw() {
    local w=$SCREEN_WIDTH h=$SCREEN_HEIGHT

    # Sky and ground: big shapes first, details later.
    rect 1 1 "$w" "$h" blue
    rect 1 $(( h - 4 )) "$w" 5 green
    circle $(( w - 10 )) 5 3 bright_yellow                      # the sun

    # Overlap demo: the red square is drawn after the cyan one, so it wins.
    rect 4 3 10 5 cyan
    rect 9 5 10 5 red
    text 5 4 "first" black
    text 10 8 "second" white

    # A fan of lines using a loop and characters instead of solid cells.
    local i
    for (( i = 0; i <= 12; i += 3 )); do
        line 24 10 $(( 24 + i * 2 )) 3 bright_white '*'
    done

    draw_house 40 $(( h - 8 )) 18 magenta

    # Clipping: this circle hangs off the left edge and nothing breaks.
    circle 2 $(( h - 6 )) 4 bright_green

    text 2 "$h" " 03-shapes  |  press q to quit " black bright_white
}

run_app
