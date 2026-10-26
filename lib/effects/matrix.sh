# lib/effects/matrix.sh - "Matrix" digital rain, as a reusable effect.
#
# Effect convention (every effect in lib/effects follows it):
#   <name>_init    create the effect's state (call from setup)
#   <name>_update  advance the state by one frame (call from update)
#   <name>_draw    draw into the virtual screen (call from draw)
#
# Effects never clear or print to the terminal. They only write cells into the
# shared virtual screen, so layering is just drawing order:
#
#     draw() {
#         matrix_draw          # background first
#         rect 10 5 30 8 blue  # then anything on top of it
#     }
#
# Customize before calling matrix_init:
#     MATRIX_COLOR=green  MATRIX_HEAD_COLOR=bright_white  MATRIX_SPACING=2
#
# Concepts: parallel indexed arrays (one entry per rain column), $RANDOM,
# integer "fixed-point" math, and modular arithmetic.

[[ -n ${_TUI_MATRIX_LOADED:-} ]] && return 0
_TUI_MATRIX_LOADED=1

MATRIX_COLOR=${MATRIX_COLOR:-green}
MATRIX_HEAD_COLOR=${MATRIX_HEAD_COLOR:-bright_white}
MATRIX_SPACING=${MATRIX_SPACING:-2}

# One entry per rain column. Positions are stored in tenths of a cell so a
# column can fall at, say, 0.4 cells per frame using integer arithmetic only.
MATRIX_X=() MATRIX_POS=() MATRIX_SPEED=() MATRIX_LEN=() MATRIX_SEED=()
MATRIX_GLYPHS=()
_MATRIX_HEAD='' _MATRIX_NEAR='' _MATRIX_BODY='' _MATRIX_TAIL=''

# Give column k a fresh drop starting above the top of the screen.
_matrix_spawn() {
    local k=$1
    MATRIX_POS[k]=$(( -10 * (RANDOM % SCREEN_HEIGHT) ))
    MATRIX_SPEED[k]=$(( 3 + RANDOM % 8 ))                      # 0.3 .. 1.0 cells/frame
    MATRIX_LEN[k]=$(( 4 + RANDOM % (SCREEN_HEIGHT / 2 + 1) ))
    MATRIX_SEED[k]=$RANDOM
}

matrix_init() {
    local x k=0 glyphs i
    if is_utf8_locale; then
        # Half-width katakana are one cell wide, like the film's rain.
        glyphs='ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789'
    else
        glyphs='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%&*+=<>'
    fi
    MATRIX_GLYPHS=()
    for (( i = 0; i < ${#glyphs}; i++ )); do
        MATRIX_GLYPHS+=("${glyphs:i:1}")
    done

    # Look up the color ids once instead of on every frame.
    if ! color_id "$MATRIX_COLOR" fg || ! color_id "$MATRIX_HEAD_COLOR" fg; then
        tui_warn "matrix_init: unknown color in MATRIX_COLOR or MATRIX_HEAD_COLOR"
        return 2
    fi
    color_id "$MATRIX_HEAD_COLOR" fg;  _MATRIX_HEAD=$REPLY
    color_id "$MATRIX_COLOR" fg;       _MATRIX_BODY=$REPLY
    # "bright_green" is brighter than "green"; fall back if there is no bright form.
    color_id "bright_$MATRIX_COLOR" fg || color_id "$MATRIX_COLOR" fg
    _MATRIX_NEAR=$REPLY
    color_id bright_black fg;          _MATRIX_TAIL=$REPLY

    MATRIX_X=() MATRIX_POS=() MATRIX_SPEED=() MATRIX_LEN=() MATRIX_SEED=()
    for (( x = 1; x <= SCREEN_WIDTH; x += MATRIX_SPACING )); do
        MATRIX_X[k]=$x
        _matrix_spawn "$k"
        k=$(( k + 1 ))
    done
}

matrix_update() {
    local k
    for k in "${!MATRIX_X[@]}"; do
        MATRIX_POS[k]=$(( MATRIX_POS[k] + MATRIX_SPEED[k] ))
        # Once the whole trail has left the bottom, start a new drop.
        if (( MATRIX_POS[k] / 10 - MATRIX_LEN[k] > SCREEN_HEIGHT )); then
            _matrix_spawn "$k"
        elif (( RANDOM % 25 == 0 )); then
            MATRIX_SEED[k]=$RANDOM      # occasionally reshuffle a column's glyphs
        fi
    done
}

matrix_draw() {
    local k j x y head len seed fg n=${#MATRIX_GLYPHS[@]}
    for k in "${!MATRIX_X[@]}"; do
        x=${MATRIX_X[k]} head=$(( MATRIX_POS[k] / 10 )) len=${MATRIX_LEN[k]} seed=${MATRIX_SEED[k]}
        for (( j = 0; j < len; j++ )); do
            y=$(( head - j ))
            if (( y < 1 )); then break; fi
            if (( y > SCREEN_HEIGHT )); then continue; fi
            if   (( j == 0 ));           then fg=$_MATRIX_HEAD
            elif (( j < 3 ));            then fg=$_MATRIX_NEAR
            elif (( j < len * 2 / 3 ));  then fg=$_MATRIX_BODY
            else                              fg=$_MATRIX_TAIL
            fi
            # A glyph depends on the column seed and the row, so it stays put
            # while the drop passes (less output) but differs between rows.
            _fb_put "$x" "$y" "${MATRIX_GLYPHS[(seed + y * 7) % n]}" "$fg" ''
        done
    done
}
