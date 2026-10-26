#!/usr/bin/env bash
# 08-job-queue.sh - mock scheduler queue grouped by job state.
#
# Run:   ./examples/08-job-queue.sh                       interactive view
#        ./examples/08-job-queue.sh --state RUNNING       start filtered
#        ./examples/08-job-queue.sh --user alice --plain  plain text, for pipes
#        ./examples/08-job-queue.sh --plain | grep gpu | wc -l
#        ./examples/08-job-queue.sh --file my-squeue.txt
#
# Keys (interactive): a=all r=running p=pending c=completed f=failed, q=quit
#
# Concepts:
#   * long-option argument parsing   while (( $# )); do case $1 in ... shift
#   * awk as a filter                awk -v state="$x" '$5 == state'
#   * sort / uniq -c                 counting jobs per state
#   * arrays of records              one line per job, split with read
#   * tests                          [[ -r $file ]], [[ -z $filter ]]
#   * two output modes               TUI for people, plain text for pipelines

set -euo pipefail
here=$(dirname -- "${BASH_SOURCE[0]}")

usage() {
    cat >&2 <<EOF
usage: ${0##*/} [--state STATE] [--user USER] [--file FILE] [--plain]
  STATE is RUNNING, PENDING, COMPLETED or FAILED (case-insensitive).
EOF
}

# --- Parse arguments --------------------------------------------------------
job_file="$here/../data/jobs.txt"
state_filter=''
user_filter=''
plain=0
while (( $# > 0 )); do
    case $1 in
        --state) [[ $# -ge 2 ]] || { usage; exit 2; }; state_filter=${2^^}; shift ;;
        --user)  [[ $# -ge 2 ]] || { usage; exit 2; }; user_filter=$2; shift ;;
        --file)  [[ $# -ge 2 ]] || { usage; exit 2; }; job_file=$2; shift ;;
        --plain) plain=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; usage; exit 2 ;;
    esac
    shift
done

case $state_filter in
    ''|RUNNING|PENDING|COMPLETED|FAILED) ;;
    *) printf 'invalid state: %s\n' "$state_filter" >&2; exit 2 ;;
esac
if [[ ! -r $job_file ]]; then
    printf 'cannot read job file: %s\n' "$job_file" >&2
    exit 2
fi

states=(RUNNING PENDING FAILED COMPLETED)   # display order

# select_jobs - print matching job lines (no header) on stdout.
# awk does the filtering: -v passes shell values in as awk variables.
select_jobs() {
    awk -v state="$state_filter" -v user="$user_filter" '
        NR == 1 { next }                                   # skip the header
        NF < 7  { next }                                   # skip malformed lines
        (state == "" || $5 == state) && (user == "" || $2 == user)
    ' "$job_file"
}

# --- Plain mode: a pipeline-friendly table ---------------------------------------
if (( plain )); then
    output=$(select_jobs)
    if [[ -z $output ]]; then
        printf 'no jobs match\n' >&2
        exit 1                      # "nothing found" is a status, not an output
    fi
    head -n 1 "$job_file"
    # sort by state, then job id. -k5,5 = field 5 only; -b ignores the leading
    # blanks, which otherwise count as part of the field in aligned columns.
    printf '%s\n' "$output" | sort -b -k5,5 -k1,1n
    exit 0
fi

# --- Interactive mode ---------------------------------------------------------
source "$here/../tui.sh"

jobs_list=()
counts=''

load_jobs() {
    mapfile -t jobs_list < <(select_jobs)
    # "RUNNING 4 PENDING 4 ..." from a classic count pipeline
    counts=$(awk 'NR > 1 { print $5 }' "$job_file" | sort | uniq -c |
             awk '{ printf "%s:%s  ", $2, $1 }')
}

setup() {
    load_jobs
}

on_key() {
    case $1 in
        a|A) state_filter='' ;;
        r|R) state_filter=RUNNING ;;
        p|P) state_filter=PENDING ;;
        c|C) state_filter=COMPLETED ;;
        f|F) state_filter=FAILED ;;
        *)   return 0 ;;
    esac
    load_jobs
}

state_color() {
    case $1 in
        RUNNING)   REPLY=bright_green ;;
        PENDING)   REPLY=bright_yellow ;;
        COMPLETED) REPLY=bright_blue ;;
        *)         REPLY=bright_red ;;
    esac
}

draw() {
    local y=4 state job id user part name st time nodes shown buf

    rect 1 1 "$SCREEN_WIDTH" 1 magenta
    text 2 1 "Job queue  |  filter: ${state_filter:-ALL}${user_filter:+  user: $user_filter}" bright_white
    text 2 2 "$counts" white

    if (( ${#jobs_list[@]} == 0 )); then
        text 2 4 "No jobs match this filter." bright_red
    fi

    # Group by state: one heading per state, then that state's jobs.
    for state in "${states[@]}"; do
        shown=0
        for job in "${jobs_list[@]}"; do
            read -r id user part name st time nodes <<< "$job"
            [[ $st == "$state" ]] || continue
            # Leave the last two rows free for the footer.
            if (( y >= SCREEN_HEIGHT - 2 )); then
                text 4 "$y" "... more jobs (enlarge the terminal or filter)" bright_black
                break 2                        # leave both loops
            fi
            if (( ! shown )); then
                state_color "$state"
                rect 2 "$y" 30 1 "$REPLY"
                text 3 "$y" "$state" black
                y=$(( y + 1 ))
                shown=1
            fi
            printf -v buf '%-6s %-7s %-9s %-16s %9s %3s nodes' \
                "$id" "$user" "$part" "$name" "$time" "$nodes"
            text 4 "$y" "$buf" white
            y=$(( y + 1 ))
        done
        if (( shown )); then y=$(( y + 1 )); fi
    done

    text 2 "$SCREEN_HEIGHT" "a:all r:running p:pending c:completed f:failed  q:quit" bright_black
}

run_app
