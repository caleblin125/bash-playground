#!/usr/bin/env bash
# 04-bouncing-ball.sh - a ball that bounces off the edges of the screen.
#
# Run:   ./examples/04-bouncing-ball.sh            (q quits, arrows nudge the ball)
#        TUI_FPS=30 ./examples/04-bouncing-ball.sh
#
# Concepts:
#   * global state between frames    x, y, dx, dy live outside the hooks
#   * conditionals                   if (( x <= 1 || x >= max )); then ...
#   * arithmetic                     $(( x + dx )), unary minus, ternaries
#   * frame timing                   update/draw run TUI_FPS times per second
#   * arrays as a history buffer     trail_x / trail_y
#   * case statements                handle keys in on_key

set -euo pipefail
here=$(dirname -- "${BASH_SOURCE[0]}")
source "$here/../tui.sh"

radius=1
colors=(bright_red bright_yellow bright_green bright_cyan bright_magenta)
color_index=0
bounces=0
trail_x=() trail_y=()

setup() {
    # Start near the middle, moving diagonally.
    x=$(( SCREEN_WIDTH / 2 ))
    y=$(( SCREEN_HEIGHT / 2 ))
    dx=2
    dy=1
}

# Called whenever the ball touches a wall.
bounce() {
    bounces=$(( bounces + 1 ))
    color_index=$(( (color_index + 1) % ${#colors[@]} ))
}

update() {
    x=$(( x + dx ))
    y=$(( y + dy ))

    # The ball is 2*radius*2+1 columns wide and 2*radius+1 rows tall.
    local min_x=$(( 1 + 2 * radius )) max_x=$(( SCREEN_WIDTH - 2 * radius ))
    local min_y=$(( 1 + radius )) max_y=$(( SCREEN_HEIGHT - 1 - radius ))

    if (( x <= min_x )); then
        x=$min_x; dx=$(( -dx )); bounce
    elif (( x >= max_x )); then
        x=$max_x; dx=$(( -dx )); bounce
    fi
    if (( y <= min_y )); then
        y=$min_y; dy=$(( -dy )); bounce
    elif (( y >= max_y )); then
        y=$max_y; dy=$(( -dy )); bounce
    fi

    # Remember the last 8 positions for a fading trail.
    trail_x+=("$x") trail_y+=("$y")
    if (( ${#trail_x[@]} > 8 )); then
        trail_x=("${trail_x[@]:1}") trail_y=("${trail_y[@]:1}")
    fi
}

on_key() {
    case $1 in
        UP)    dy=-1 ;;
        DOWN)  dy=1 ;;
        LEFT)  dx=-2 ;;
        RIGHT) dx=2 ;;
        +)     (( radius < 4 )) && radius=$(( radius + 1 )) ;;
        -)     (( radius > 0 )) && radius=$(( radius - 1 )) ;;
    esac
    return 0
}

draw() {
    local i
    for i in "${!trail_x[@]}"; do
        text "${trail_x[i]}" "${trail_y[i]}" '.' bright_black
    done
    circle "$x" "$y" "$radius" "${colors[color_index]}"

    text 1 "$SCREEN_HEIGHT" \
        " pos=($x,$y) vel=($dx,$dy) bounces=$bounces  arrows: steer  +/-: size  q: quit " \
        black white
}

run_app
