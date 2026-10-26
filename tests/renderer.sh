#!/usr/bin/env bash
# tests/renderer.sh - tests for differential rendering. Run: bash tests/renderer.sh
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." || exit 1
source tests/assert.sh
source tui.sh

printf 'renderer:\n'

E=$'\e'

fb_init 8 3
render_invalidate
_render_build
first=$TUI_FRAME_OUT
assert_eq "$E[0m$E[2J" "${first:0:8}" 'first frame clears the terminal once'
[[ $first == *"$E[1;1H"* && $first == *"$E[3;1H"* ]]
assert_eq 0 $? 'first frame draws every row'

_render_build
assert_eq '' "$TUI_FRAME_OUT" 'identical frame produces no output'

clear
text 4 2 'X' red
_render_build
assert_eq "$E[2;4H$E[0;31;49mX$E[0m" "$TUI_FRAME_OUT" 'one changed cell -> one cursor move and one cell'

clear
text 4 2 'X' red
_render_build
assert_eq '' "$TUI_FRAME_OUT" 'redrawing the same scene sends nothing'

clear
text 2 1 'ab' green
text 6 1 'cd' green
_render_build
assert_eq "$E[1;2H$E[0;32;49mab$E[0;39;49m  $E[0;32;49mcd$E[2;4H$E[0;39;49m $E[0m" \
    "$TUI_FRAME_OUT" 'changed span per row, colors switch only where needed'
[[ $TUI_FRAME_OUT != *"$E[2J"* ]]
assert_eq 0 $? 'later frames never clear the whole screen'

clear blue
_render_build
out=$TUI_FRAME_OUT
assert_eq 1 "$([[ $out == *'39;44m        '* ]] && echo 1)" 'background change repaints the full row'

render_invalidate
_render_build
assert_eq "$E[0m$E[2J" "${TUI_FRAME_OUT:0:8}" 'render_invalidate forces a full redraw'

# Terminal setup is undone by tui_restore (colors, wrapping, cursor, screen).
out=$(tui_init; tui_restore; tui_restore)
assert_eq 1 "$([[ $out == *"$E[?25l"* ]] && echo 1)" 'tui_init hides the cursor'
expected="$E[0m$E[?7h$E[?25h$E[?1049l"
assert_eq "$expected" "${out: -${#expected}}" 'tui_restore resets colors and shows the cursor'
[[ $out != *"$E[?1049l"*"$E[?1049l"* ]]
assert_eq 0 $? 'tui_restore is safe to call twice'

# Layering: an effect drawn first stays behind later drawing.
fb_init 20 6
MATRIX_SPACING=1 matrix_init
for _ in {1..30}; do matrix_update; done
clear
matrix_draw
rect 5 2 10 3 black
text 6 3 'PANEL' white
fb_cell 6 3;  assert_eq 'P' "$CELL_CH" 'text on top of the rain'
fb_cell 14 2; assert_eq ' ' "$CELL_CH" 'panel hides the rain behind it'

test_summary
