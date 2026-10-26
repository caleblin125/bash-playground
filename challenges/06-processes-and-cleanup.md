# 06 — Processes, timing, cleanup and shell safety

**Examples:** `examples/06-process-monitor.sh`, `examples/07-matrix-dashboard.sh`,
`lib/effects/spinner.sh`, `run_app` in `tui.sh`
**You will learn:** `sleep`, background jobs with `&`, `$!`, `wait`, `kill`,
`trap`, `jobs`, `ps`; and what `set -euo pipefail` does and does not do.

## 1. Run it

```bash
./examples/07-matrix-dashboard.sh     # watch "Syncing /scratch" finish, then press Ctrl+C
echo "status: $?"                     # 130 = 128 + SIGINT (2)
./examples/06-process-monitor.sh      # find your own bash and the example itself
```

After Ctrl+C your cursor, colors and normal screen come back: that is `trap`
at work.

## 2. Concepts

### Background jobs

```bash
sleep 2 &                 # & runs a command in the background
worker_pid=$!             # $! is the PID of the most recent background job

wait "$worker_pid"        # block until it finishes...
printf 'Worker completed with status %d\n' "$?"   # ...and get its exit status
```

- `kill -0 "$pid"` sends no signal; it just tests whether the process is
  still alive. The spinner effect polls this every frame and calls `wait`
  once the process is gone to collect its status.
- `kill "$pid"` sends SIGTERM. **Only signal processes your script started**
  (PIDs you saved from `$!`). Never kill by name or guess PIDs in a shared
  machine like a login node.
- `jobs`, `fg` and `bg` manage background jobs in an *interactive* shell:
  run `sleep 30 &` then `jobs` in your terminal.
- `ps -o pid,ppid,stat,etime,cmd -p "$pid"` shows details about one process;
  `ps -ef --forest` shows who started whom.

### Timing

`sleep 0.1` pauses a tenth of a second. An animation loop that does work and
then sleeps a fixed time runs slower than intended, so `run_app` measures how
long each frame took (`$EPOCHREALTIME`) and only waits for the remainder. It
waits with `read -t`, which doubles as the keyboard check.

Refreshing expensive data less often than you redraw is a common pattern:
`06-process-monitor.sh` runs `ps` once per second (`TUI_FRAME % TUI_FPS == 0`)
while drawing 15 frames per second.

### trap and cleanup

`trap 'commands' SIGNALS` runs commands when the script receives a signal or
exits:

```bash
tmp=$(mktemp)
trap 'rm -f -- "$tmp"' EXIT                       # runs on any exit
trap 'printf "\ninterrupted\n" >&2; exit 130' INT  # Ctrl+C
```

`run_app` traps `EXIT`, `INT`, `TERM` and `HUP`. On any of them it calls
your `cleanup` hook once, then restores the terminal. Put "undo" work in
`cleanup`: kill your background jobs, delete temp files, print a summary.

### Shell safety options

```bash
#!/usr/bin/env bash
set -euo pipefail
```

| Option | Effect |
|---|---|
| `-u` | using an unset variable is an error (catches typos like `$nmae`) |
| `-o pipefail` | a pipeline fails if *any* part fails, not just the last |
| `-e` | exit when a command fails |

They help, but they do **not** make a script safe automatically. `set -e` in
particular has many exceptions:

- It is ignored in `if` conditions, in `while` conditions, and on the left of
  `&&` / `||` — so `grep -q x file && echo yes` never exits.
- A function called as a condition (`if myfunc; then`) runs with `-e` off
  inside it.
- `(( count++ ))` returns status 1 when `count` was 0, so **it kills the
  script**. Write `count=$(( count + 1 ))` instead.
- `local var=$(failing_cmd)` succeeds because `local` succeeded; declare
  first, assign second.
- `grep` returning 1 for "no matches" is a normal outcome, not an error, but
  `set -e` treats it as one. Handle it deliberately:
  `matches=$(grep ...) || status=$?` (see `05-log-filter.sh`).

Use the options as a safety net, and still check the things that matter with
explicit `if` statements and useful messages on stderr. An error *message* is
for people; the exit *status* is for programs — set both.

### Debugging tools

```bash
bash -n script.sh               # parse only: syntax errors without running
bash -x script.sh               # print each command as it runs (+ prefix)
PS4='+ ${LINENO}: ' bash -x script.sh    # include line numbers in the trace
set -x; risky_part; set +x      # trace only one section
TUI_FRAMES=2 bash -x ./examples/04-bouncing-ball.sh 2> trace.txt   # TUI apps: trace to a file
```

## 3. Modification challenge — a pretend job runner

Copy `07-matrix-dashboard.sh` to `my-runner.sh` and change `setup` so it
starts **three** background "jobs" of different lengths and adds a spinner
for each:

```bash
for i in 1 2 3; do
    random_int 2 8
    ( sleep "$REPLY"; exit $(( RANDOM % 3 == 0 )) ) &   # some jobs "fail"
    spinner_add 0 0 "job $i (${REPLY}s)" "$!"
    worker_pids+=("$!")
done
```

1. Position the spinners on separate rows inside the panel.
2. Show `N/3 jobs finished` in the footer using `spinner_done`.
3. In `cleanup`, kill only the jobs in `worker_pids` that are still running,
   then `wait` for them. Quit while jobs are running and confirm with
   `ps -ef | grep '[s]leep'` that none were left behind.
4. When every job has finished, call `quit` after showing the results for two
   seconds (count frames: `2 * TUI_FPS`).

## 4. Extension

Limit concurrency: put 10 jobs in a queue array but run at most 3 at a time.
In `update`, whenever a running job finishes, start the next queued one. This
is a tiny version of what an HPC scheduler does.

## 5. Debugging prompt

This script should count finished workers, but it stops silently after the
first one, and sometimes it kills the user's terminal session. Find both bugs.

```bash
#!/usr/bin/env bash
set -euo pipefail
done_count=0
sleep 1 &
sleep 2 &
for pid in $(jobs -p); do
    wait "$pid"
    (( done_count++ ))
    echo "finished: $done_count"
done
trap 'kill $$' EXIT
```

<details><summary>Hints</summary>

- `(( done_count++ ))` evaluates to the *old* value, 0, which is "false", so
  the command returns status 1 and `set -e` exits. Use
  `done_count=$(( done_count + 1 ))`.
- `$$` is the PID of the **script itself** (and, if the script is sourced, of
  your interactive shell!), not a worker. Save worker PIDs from `$!` and kill
  those. A trap must also be set *before* the code it protects.
</details>
