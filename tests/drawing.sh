#!/usr/bin/env bash
# tests/drawing.sh - tests for the virtual screen and shapes. Run: bash tests/drawing.sh
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." || exit 1
source tests/assert.sh
source tui.sh

printf 'drawing:\n'

# row N -> REPLY = the characters of row N (1-based)
row() { REPLY=${_FB_CH[$1 - 1]}; }

fb_init 10 4
assert_eq '10x4' "${SCREEN_WIDTH}x${SCREEN_HEIGHT}" 'fb_init sets the size'
assert_eq 4 "${#_FB_CH[@]}" 'one string per row'
row 1; assert_eq '          ' "$REPLY" 'new screen is blank'

# text and clipping
text 3 2 'hello'
row 2; assert_eq '  hello   ' "$REPLY" 'text at (3,2)'
text 8 1 'abcdef'
row 1; assert_eq '       abc' "$REPLY" 'text clipped on the right'
text -1 3 'xyz!'
row 3; assert_eq 'z!        ' "$REPLY" 'text clipped on the left'
text 1 0 'nope'; text 1 5 'nope'
row 4; assert_eq '          ' "$REPLY" 'text above/below the screen is ignored'
text 1 4 $'a\tb'
row 4; assert_eq 'a b       ' "$REPLY" 'control characters become spaces'
for y in 1 2 3 4; do row "$y"; assert_eq 10 "${#REPLY}" "row $y keeps its width"; done

# colors
clear
text 1 1 'hi' red
fb_cell 1 1; assert_eq 'h 31 49' "$CELL_CH $CELL_FG $CELL_BG" 'text color stored per cell'
fb_cell 3 1; assert_eq '  39 49' "$CELL_CH $CELL_FG $CELL_BG" 'cells after text untouched'
assert_status 1 'fb_cell off screen' -- fb_cell 11 1

# rect: solid and character modes, overlap order
clear
rect 2 2 3 2 blue
fb_cell 2 2; assert_eq '44' "$CELL_BG" 'solid rect paints background'
fb_cell 5 2; assert_eq '49' "$CELL_BG" 'rect stops at its width'
rect 3 1 2 2 red '#'
row 1; assert_eq '  ##      ' "$REPLY" 'character rect'
fb_cell 3 2; assert_eq '# 31 44' "$CELL_CH $CELL_FG $CELL_BG" 'later draw wins, keeps background'
text 2 3 'ok' white
fb_cell 2 3; assert_eq 'o 37 44' "$CELL_CH $CELL_FG $CELL_BG" 'text on a rect keeps its background'

clear
rect -5 -5 100 100 green '.'
row 1; assert_eq '..........' "$REPLY" 'huge rect is clipped'
row 4; assert_eq '..........' "$REPLY" 'huge rect reaches the last row'
clear
rect 4 2 0 3 red '#'
row 2; assert_eq '          ' "$REPLY" 'zero-width rect draws nothing'

# validation
assert_status 2 'rect rejects missing args'  -- rect 1 2 3
assert_status 2 'rect rejects non-integers'  -- rect 1 two 3 4 red
assert_status 2 'rect rejects negative size' -- rect 1 1 -3 2 red
assert_status 2 'rect rejects bad color'     -- rect 1 1 3 2 purple
assert_status 2 'circle rejects radius -1'   -- circle 5 5 -1 red
assert_status 2 'text rejects bad coords'    -- text x 1 hi
assert_status 2 'clear rejects bad color'    -- clear nope

# line
fb_init 5 5
line 1 1 5 5 white '\'
for y in 1 2 3 4 5; do
    fb_cell "$y" "$y"; assert_eq '\' "$CELL_CH" "diagonal line passes ($y,$y)"
done
clear
line 5 3 1 3 white '-'
row 3; assert_eq '-----' "$REPLY" 'right-to-left horizontal line'
clear
line -10 2 20 2 white '='
row 2; assert_eq '=====' "$REPLY" 'line clipped at both ends'

# circle
fb_init 11 5
circle 6 3 0 red '*'
row 3; assert_eq '     *     ' "$REPLY" 'radius 0 is one cell'
clear
circle 6 3 2 red 'o'
row 3; assert_eq ' ooooooooo ' "$REPLY" 'circle middle row is widest'
row 1; assert_eq '   ooooo   ' "$REPLY" 'circle top row is narrower'
row 5; assert_eq '   ooooo   ' "$REPLY" 'circle bottom row mirrors the top'
circle 1 1 3 blue '#'
fb_cell 1 1; assert_eq '#' "$CELL_CH" 'circle clipped at the corner'

# clear with color
clear cyan
fb_cell 4 4; assert_eq '  39 46' "$CELL_CH $CELL_FG $CELL_BG" 'clear with a background color'
clear
fb_cell 4 4; assert_eq '49' "$CELL_BG" 'clear resets to default background'

test_summary
