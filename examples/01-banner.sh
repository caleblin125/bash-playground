#!/usr/bin/env bash
# 01-banner.sh - print a colored banner with the hostname and date.
#
# Run:   ./examples/01-banner.sh
#        ./examples/01-banner.sh "HPC Club"        # custom title
#
# Concepts:
#   * variables and expansion        name=value, "$name"
#   * command substitution           $(hostname), $(date)
#   * default values                 ${1:-default}
#   * environment variables          $USER, $SHELL, $TERM, $HOME
#   * printf formatting              %s, %-12s, \n
#   * ANSI color escape sequences    \e[1;36m ... \e[0m
#
# This lesson does not use the framework at all: it prints straight to the
# terminal so you can see the raw escape codes the framework uses internally.

set -euo pipefail

# $1 is the first argument. ${1:-...} supplies a default when it is missing.
title=${1:-"Bash Playground"}

# Command substitution runs a command and captures its output as a string.
# `||` runs the fallback if hostname is missing or fails.
host=$(hostname 2>/dev/null || uname -n)
today=$(date '+%A %d %B %Y, %H:%M')
kernel=$(uname -sr)

# Color codes. In single quotes nothing is expanded; printf turns \e into ESC.
bold_cyan='\e[1;36m'
yellow='\e[33m'
green='\e[32m'
reset='\e[0m'

# Build a line of '=' as wide as the title plus padding.
width=$(( ${#title} + 8 ))          # ${#var} is the length of a string
rule=$(printf '%*s' "$width" '')    # $width spaces...
rule=${rule// /=}                   # ...with every space replaced by '='

# printf's first argument is the format; %b expands backslash escapes in an
# argument, %s inserts it unchanged. Always quote "$variables".
printf '%b%s%b\n' "$bold_cyan" "$rule" "$reset"
printf '%b    %s    %b\n' "$bold_cyan" "$title" "$reset"
printf '%b%s%b\n\n' "$bold_cyan" "$rule" "$reset"

# %-10s pads to 10 characters, left-aligned, so the values line up.
printf '%b%-10s%b %s\n' "$yellow" "Host:"   "$reset" "$host"
printf '%b%-10s%b %s\n' "$yellow" "User:"   "$reset" "${USER:-$(id -un)}"
printf '%b%-10s%b %s\n' "$yellow" "Date:"   "$reset" "$today"
printf '%b%-10s%b %s\n' "$yellow" "Kernel:" "$reset" "$kernel"
printf '%b%-10s%b %s\n' "$yellow" "Shell:"  "$reset" "${SHELL:-unknown} (Bash $BASH_VERSION)"
printf '%b%-10s%b %s\n' "$yellow" "Terminal:" "$reset" "${TERM:-unknown}"
printf '\n%bReady.%b\n' "$green" "$reset"
