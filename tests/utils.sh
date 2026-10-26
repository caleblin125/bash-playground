#!/usr/bin/env bash
# tests/utils.sh - tests for lib/utils.sh. Run: bash tests/utils.sh
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." || exit 1
source tests/assert.sh
source tui.sh

printf 'utils:\n'

assert_status 0 'is_int accepts 42'        -- is_int 42
assert_status 0 'is_int accepts -7'        -- is_int -7
assert_status 1 'is_int rejects 3.5'       -- is_int 3.5
assert_status 1 'is_int rejects empty'     -- is_int ''
assert_status 1 'is_int rejects code'      -- is_int 'a[$(date)]'
assert_status 1 'is_uint rejects -1'       -- is_uint -1

clamp 15 0 10;  assert_eq 10 "$REPLY" 'clamp above max'
clamp -3 0 10;  assert_eq 0 "$REPLY"  'clamp below min'
clamp 4 0 10;   assert_eq 4 "$REPLY"  'clamp inside range'

repeat_char '#' 5; assert_eq '#####' "$REPLY" 'repeat_char 5'
repeat_char '&' 3; assert_eq '&&&' "$REPLY"   'repeat_char handles &'
repeat_char x 0;   assert_eq '' "$REPLY"      'repeat_char 0 is empty'

ok=1
for _ in {1..200}; do
    random_int 3 6
    if (( REPLY < 3 || REPLY > 6 )); then ok=0; fi
done
assert_eq 1 "$ok" 'random_int stays in range'

color_code red fg;            assert_eq 31 "$REPLY"       'red foreground'
color_code red bg;            assert_eq 41 "$REPLY"       'red background'
color_code bright_blue fg;    assert_eq 94 "$REPLY"       'bright blue foreground'
color_code gray bg;           assert_eq 100 "$REPLY"      'gray background'
color_code default fg;        assert_eq 39 "$REPLY"       'default foreground'
color_code 208 fg;            assert_eq '38;5;208' "$REPLY" '256-color foreground'
assert_status 1 'unknown color name'  -- color_code purple fg
assert_status 1 'color number > 255'  -- color_code 300 fg

TUI_WIDTH=33 TUI_HEIGHT=11 screen_size
assert_eq '33x11' "${SCREEN_WIDTH}x${SCREEN_HEIGHT}" 'screen_size honors TUI_WIDTH/TUI_HEIGHT'

test_summary
