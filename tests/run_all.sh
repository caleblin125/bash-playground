#!/usr/bin/env bash
# tests/run_all.sh - check everything: syntax, unit tests, and example smoke runs.
#
# Run:   bash tests/run_all.sh
#
# 1. `bash -n` parses every script without running it (syntax check).
# 2. The unit tests exercise the framebuffer, shapes, clipping and utilities.
# 3. Every example runs briefly with a fixed screen size and no terminal:
#    TUI_FRAMES=3 makes run_app stop by itself after three frames.

set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." || exit 1

failures=0
fail() { printf '  FAIL  %s\n' "$*"; failures=$(( failures + 1 )); }

printf '== Syntax check (bash -n)\n'
while IFS= read -r file; do
    if bash -n "$file"; then
        printf '  ok    %s\n' "$file"
    else
        fail "$file"
    fi
done < <(find . -name '*.sh' -not -path './.git/*' | sort)

printf '\n== Unit tests\n'
for t in tests/utils.sh tests/drawing.sh tests/renderer.sh; do
    bash "$t" || fail "$t"
done

printf '\n== Example smoke tests\n'
# run_example DESCRIPTION EXPECTED_STATUS COMMAND...
run_example() {
    local description=$1 expected=$2 status=0
    shift 2
    TUI_FRAMES=3 TUI_WIDTH=70 TUI_HEIGHT=22 TUI_FPS=30 \
        timeout 30 "$@" </dev/null >/dev/null 2>/tmp/bash-playground-err.$$ || status=$?
    if (( status == expected )); then
        printf '  ok    %s\n' "$description"
    else
        fail "$description (status $status, expected $expected)"
        sed 's/^/        /' /tmp/bash-playground-err.$$
    fi
    rm -f /tmp/bash-playground-err.$$
}

run_example '01 banner'                0 bash examples/01-banner.sh
run_example '02 progress bar'          0 bash examples/02-progress.sh 10 0
run_example '03 shapes'                0 bash examples/03-shapes.sh
run_example '04 bouncing ball'         0 bash examples/04-bouncing-ball.sh
run_example '05 log filter (errors)'   1 bash examples/05-log-filter.sh data/sample.log
run_example '05 log filter (warnings)' 0 bash examples/05-log-filter.sh -l WARN data/sample.log
run_example '05 log filter (missing)'  2 bash examples/05-log-filter.sh no-such-file.log
run_example '05 log filter (empty)'    0 bash examples/05-log-filter.sh /dev/null
run_example '05 log filter (bad opt)'  2 bash examples/05-log-filter.sh -z data/sample.log
run_example '06 process monitor'       0 bash examples/06-process-monitor.sh --mock
run_example '07 matrix dashboard'      0 bash examples/07-matrix-dashboard.sh
run_example '08 job queue'             0 bash examples/08-job-queue.sh
run_example '08 job queue --plain'     0 bash examples/08-job-queue.sh --plain --state failed
run_example '08 job queue no match'    1 bash examples/08-job-queue.sh --plain --user nobody
run_example '08 job queue bad state'   2 bash examples/08-job-queue.sh --state sleeping

printf '\n== Signal cleanup\n'
# Start an endless app, stop it with SIGTERM, and check the terminal was restored.
# (Background jobs in scripts ignore SIGINT, so TERM stands in for Ctrl+C here;
# both go through the same trap handler.)
sig_out=$(mktemp)
TUI_WIDTH=40 TUI_HEIGHT=10 bash examples/04-bouncing-ball.sh </dev/null >"$sig_out" 2>&1 &
app_pid=$!
sleep 1
kill -TERM "$app_pid" 2>/dev/null
status=0
wait "$app_pid" || status=$?
if (( status == 143 )) && [[ $(tail -c 30 "$sig_out") == *$'\e[?25h\e[?1049l' ]]; then
    printf '  ok    SIGTERM exits with 143 and restores the terminal\n'
else
    fail "SIGTERM cleanup (status $status)"
fi
rm -f -- "$sig_out"

printf '\n'
if (( failures )); then
    printf '%d check(s) FAILED\n' "$failures"
    exit 1
fi
printf 'All checks passed.\n'
