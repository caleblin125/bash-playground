#!/usr/bin/env bash
# 05-log-filter.sh - pull warnings and errors out of a log and summarize them.
#
# Run:   ./examples/05-log-filter.sh data/sample.log
#        cat data/sample.log | ./examples/05-log-filter.sh          # stdin
#        ./examples/05-log-filter.sh -l ERROR data/sample.log       # errors only
#        ./examples/05-log-filter.sh -n data/sample.log > out.txt   # no colors
#        ./examples/05-log-filter.sh missing.log; echo "status=$?"
#
# Exit status: 0 = no errors found, 1 = errors found, 2 = usage or file problem.
# Scripts that "return" a verdict through their exit status can be chained:
#     ./examples/05-log-filter.sh data/sample.log > /dev/null || echo "check the log!"
#
# Concepts:
#   * getopts option parsing         -n -l LEVEL
#   * stdin vs a file argument       [[ -t 0 ]], "-" convention
#   * redirection                    > 2> >> < /dev/null
#   * mktemp + trap                  temporary files that clean themselves up
#   * pipelines                      grep | sed | awk | sort | uniq | head
#   * grep's exit status             0 = match, 1 = no match, 2 = error
#   * stdout for results, stderr for messages

set -euo pipefail

usage() {
    printf 'usage: %s [-n] [-l WARN|ERROR|ALL] [FILE|-]\n' "${0##*/}" >&2
    printf '  Reads FILE, or standard input when FILE is "-" or omitted.\n' >&2
}

use_color=1
level=ALL
while getopts ':nl:h' opt; do
    case $opt in
        n) use_color=0 ;;
        l) level=${OPTARG^^} ;;          # ^^ upper-cases the value
        h) usage; exit 0 ;;
        :) printf 'option -%s needs a value\n' "$OPTARG" >&2; usage; exit 2 ;;
        *) printf 'unknown option -%s\n' "$OPTARG" >&2; usage; exit 2 ;;
    esac
done
shift $(( OPTIND - 1 ))                  # drop the options, keep the file name

case $level in
    ALL)   pattern='WARN|ERROR' ;;
    WARN)  pattern='WARN' ;;
    ERROR) pattern='ERROR' ;;
    *) printf 'level must be WARN, ERROR or ALL (got %s)\n' "$level" >&2; exit 2 ;;
esac

# Colors only make sense on a terminal. [[ -t 1 ]] tests whether stdout is one,
# so `... > file` or `... | less` get plain text automatically.
[[ -t 1 ]] || use_color=0

# Copy the input to a temporary file so we can read it more than once.
tmp=$(mktemp "${TMPDIR:-/tmp}/logfilter.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT             # only ever removes the file we created

file=${1:--}
if [[ $file == - ]]; then
    if [[ -t 0 ]]; then
        printf 'No input: give a file name or pipe a log into this script.\n' >&2
        usage
        exit 2
    fi
    cat > "$tmp"                         # read all of stdin
elif [[ ! -e $file ]]; then
    printf 'error: %s: no such file\n' "$file" >&2
    exit 2
elif [[ ! -r $file ]]; then
    printf 'error: %s: permission denied\n' "$file" >&2
    exit 2
else
    cp -- "$file" "$tmp"
fi

if [[ ! -s $tmp ]]; then                 # -s: file exists and is not empty
    printf 'Input is empty; nothing to report.\n' >&2
    exit 0
fi

# grep returns 1 when nothing matches. That is not a failure here, so handle it
# explicitly instead of letting `set -e` stop the script.
status=0
matches=$(grep -E " ($pattern) " "$tmp") || status=$?
if (( status == 1 )); then
    printf 'No %s lines found.\n' "$level" >&2
    exit 0
elif (( status > 1 )); then
    printf 'grep failed (status %d)\n' "$status" >&2
    exit 2
fi

# Normalize the matching lines once, then reuse the result:
# sed: drop the date, squeeze runs of spaces, turn "job 1006:" into "job-1006:"
#      using a capture group (\1 = whatever ([0-9]+) matched), and remove the
#      colon after the source name.
cleaned=$(printf '%s\n' "$matches" |
    sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2} //; s/ +/ /g; s/ job ([0-9]+):/ job-\1:/; s/^([^ ]+ [^ ]+ [^ ]+):/\1/')

# awk: split each line into fields ($1 time, $2 level, $3 source, rest message)
#      and print a colored, aligned table. Note awk has its own syntax:
#      inside the single quotes, $1 means "field 1", not a shell variable.
printf '%s\n' "$cleaned" |
    awk -v color="$use_color" '
        {
            msg = ""
            for (i = 4; i <= NF; i++) msg = msg " " $i
            c = ($2 == "ERROR") ? "\033[31m" : "\033[33m"
            if (!color) c = ""
            r = color ? "\033[0m" : ""
            printf "%s  %s%-5s%s  %-10s%s\n", $1, c, $2, r, $3, msg
        }'

# Summary: count lines per level, then the noisiest sources.
# `uniq -c` only merges *adjacent* duplicates, which is why `sort` comes first.
printf '\nSummary:\n'
printf '%s\n' "$cleaned" | cut -d' ' -f2 | sort | uniq -c |
    awk '{ printf "  %-6s %d\n", $2, $1 }'

printf 'Top sources:\n'
printf '%s\n' "$cleaned" | cut -d' ' -f3 | sort | uniq -c |
    sort -rn | head -n 3 | awk '{ printf "  %-10s %d\n", $2, $1 }'

# The exit status reports whether any ERROR lines were present.
if grep -q ' ERROR ' <<< "$cleaned"; then
    exit 1
fi
exit 0
