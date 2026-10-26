# 07 — Final project: your own HPC dashboard

Build a terminal dashboard for a (real or simulated) cluster. There is no
single right answer; the goal is to combine what you practiced in lessons
01–06 into one program you understand completely.

## Requirements

Your script must:

1. **Use the framework** — `source tui.sh` and run with `run_app`, using at
   least `setup`, `update` and `draw`.
2. **Include at least one custom drawing function** that you wrote and that
   validates its arguments (e.g. `draw_box`, `bar_chart`, `gauge`,
   `sparkline`). It should live in its own file that a second script could
   `source`.
3. **Use at least one reusable effect** — `matrix_*`, `spinner_*`, or an
   effect you wrote following the `_init` / `_update` / `_draw` convention.
4. **Process data with at least one Unix pipeline** — for example
   `ps | sort | head`, `awk` over `data/jobs.txt`, `grep | sort | uniq -c`
   over `data/sample.log`, `df -h`, `free -m`, or `squeue` if you have a
   cluster account. The mock data in `data/` is enough; no cluster needed.
5. **Clean up after itself** — a `cleanup` hook that stops any background
   processes it started, removes temp files, and leaves the terminal usable
   after **q** and after Ctrl+C.
6. **Handle bad input** — missing or empty data files produce a clear message
   on screen or stderr, not a crash.
7. Start with `#!/usr/bin/env bash`, pass `bash -n`, and include a comment
   header explaining how to run it.

## Ideas

- **Node wall**: one colored tile per node from `data/nodes.txt`, load bars
  that drift over time, a ticker of the latest `WARN`/`ERROR` lines from
  `data/sample.log` scrolling along the bottom.
- **Queue watcher**: jobs per state as a bar chart from
  `awk '{print $5}' data/jobs.txt | sort | uniq -c`, keys to filter by user,
  spinners for "running" jobs.
- **Local machine monitor**: CPU from `ps`, memory from `free -m`, disk from
  `df -h`, refreshed every few seconds, with history drawn as a sparkline
  using an array as a ring buffer.
- **Simulated scheduler**: a queue of fake jobs (arrays) started as
  background `sleep` processes with at most N running at a time.

## Suggested steps

1. Sketch the screen layout on paper: where do panels go at 80×24?
2. Get the data first, without graphics: write the pipeline and print it.
3. Load it into arrays in `setup` (and refresh it in `update` every few seconds).
4. Draw it with plain `text`, then replace pieces with your custom functions.
5. Add an effect behind or beside it.
6. Add `cleanup`, then try to break your program: tiny terminal, empty data
   file, Ctrl+C during startup.

## Presenting

Be ready to explain to the group:

- one pipeline in your script, stage by stage;
- how your custom function validates its input;
- what happens, step by step, when you press Ctrl+C.

## Self-check

```bash
bash -n my-dashboard.sh
TUI_FRAMES=5 TUI_WIDTH=80 TUI_HEIGHT=24 ./my-dashboard.sh > /dev/null && echo "runs"
mv data/nodes.txt /tmp/nodes.bak; ./my-dashboard.sh; mv /tmp/nodes.bak data/nodes.txt
```
