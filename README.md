# bash-playground

A small terminal graphics framework written in plain Bash, plus a guided
workshop for learning Bash and the Unix command line by drawing things:
banners, progress bars, shapes, bouncing balls, live dashboards and Matrix rain.

The graphics are the hook, not the point. Every example is also a lesson in
variables, quoting, tests, loops, functions, arrays, pipes, redirection, text
processing and process management — the shell skills you use on an HPC cluster.

```
  ｱ     ﾊ       7               ﾄ         ｾ 2 ﾘ ﾅ
  ﾂ     ﾐ       ﾑ    CLUSTER STATUS  14:02:11     ﾇ
  4                                         ﾛ
        NODE     STATE      CPU LOAD             MEMORY
        node01   RUNNING    ########....  72%    98/128G
        node04   FAILED     ............   0%     0/128G
        ⠹  Syncing /scratch         ⠹  Polling scheduler
```
*(`examples/07-matrix-dashboard.sh` — in color, and animated.)*

## Contents

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Repository layout](#repository-layout)
- [Workshop path](#workshop-path)
- [The graphics API](#the-graphics-api)
- [Writing an app](#writing-an-app)
- [Effects](#effects)
- [How the renderer works](#how-the-renderer-works)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Requirements

| What | Needed for | Notes |
|---|---|---|
| **Bash 4.4+** (5.x recommended) | everything | Ubuntu 20.04+ ships Bash 5. macOS's built-in Bash 3.2 is too old (`brew install bash`). |
| coreutils, `grep`, `sed`, `awk` | examples 05–08 | Present on every standard Linux install. |
| `ps` from procps (`ps -eo ...`) | example 06 (live mode) | Falls back to `data/ps-sample.txt` automatically, or use `--mock`. |
| A terminal with ANSI colors | the TUI examples | Any modern terminal (GNOME Terminal, Konsole, Windows Terminal + WSL, iTerm2, VS Code). |
| UTF-8 locale | *optional* | Katakana Matrix rain and Braille spinners. ASCII is used otherwise. |
| `column` | *optional* | Mentioned in challenge 04 as an alternative to `printf`/`awk` tables. |
| `timeout` | *optional* | Used by `tests/run_all.sh` only. |

No other dependencies. No cluster access is needed — all data comes from the
mock files in `data/`.

## Quick start

```bash
git clone <this repo> bash-playground
cd bash-playground
chmod +x examples/*.sh tests/*.sh   # make the scripts executable
./examples/01-banner.sh
./examples/07-matrix-dashboard.sh    # press q to quit
```

Every interactive example quits with **q** or **Ctrl+C** and restores your
terminal on the way out.

## Repository layout

```
bash-playground/
├── tui.sh                 # source this: loads the whole framework, starts nothing
├── lib/
│   ├── utils.sh           # validation, colors, screen size, small helpers
│   ├── drawing.sh         # virtual screen + rect/line/circle/text/clear
│   ├── renderer.sh        # differential renderer, terminal setup/restore
│   └── effects/
│       ├── matrix.sh      # matrix_init / matrix_update / matrix_draw
│       └── spinner.sh     # spinner_init / spinner_add / spinner_update / spinner_draw
├── examples/              # 01..08, run in order; each runs on its own
├── challenges/            # one worksheet per lesson + the final project
├── data/                  # mock logs, node list, job queue, ps output
└── tests/                 # unit tests and tests/run_all.sh
```

## Workshop path

Work through the lessons in order. Each challenge sheet has an explanation, a
**modification challenge**, an optional **extension**, and a **debugging
prompt** with a realistic mistake to find.

| # | Run | Concepts | Worksheet |
|---|---|---|---|
| 01 | `./examples/01-banner.sh "My Title"` | variables, quoting, `$(...)`, `printf`, ANSI colors, env vars | [01 Variables and quoting](challenges/01-variables-and-quoting.md) |
| 02 | `./examples/02-progress.sh 40 0.02` | `for ((...))`, `$((...))`, `\r`, cursor control, `trap`, `sleep` | [01](challenges/01-variables-and-quoting.md), [03](challenges/03-tests-and-conditionals.md) |
| 03 | `./examples/03-shapes.sh` | `source`, functions, `$1 $#`, `local`, validation, drawing order | [03 Tests and conditionals](challenges/03-tests-and-conditionals.md), [05](challenges/05-functions-and-arrays.md) |
| 04 | `./examples/04-bouncing-ball.sh` | state, `if`/`elif`, arithmetic, frame timing, `case` | [03 Tests and conditionals](challenges/03-tests-and-conditionals.md) |
| 05 | `./examples/05-log-filter.sh data/sample.log` | pipes, redirection, `grep`/`sed`/`awk`/`sort`/`uniq`, exit status, `getopts`, `mktemp` | [02 Pipelines](challenges/02-pipelines.md), [04](challenges/04-text-processing.md) |
| 06 | `./examples/06-process-monitor.sh` | `ps`, `sort`, `head`, `mapfile`, refresh loops | [02 Pipelines](challenges/02-pipelines.md), [06](challenges/06-processes-and-cleanup.md) |
| 07 | `./examples/07-matrix-dashboard.sh` | reusable effects, arrays, layering, `&`, `$!`, `kill`, `cleanup` | [05 Functions and arrays](challenges/05-functions-and-arrays.md), [06](challenges/06-processes-and-cleanup.md) |
| 08 | `./examples/08-job-queue.sh --state running` | argument parsing, `awk -v`, grouping, two output modes | [04 Text processing](challenges/04-text-processing.md) |
| ★ | your own script | everything | [07 Final project](challenges/07-final-project.md) |

More ways to run the non-graphical examples:

```bash
cat data/sample.log | ./examples/05-log-filter.sh            # read standard input
./examples/05-log-filter.sh -l ERROR -n data/sample.log > errors.txt
./examples/05-log-filter.sh data/sample.log >/dev/null || echo "log has errors"
./examples/08-job-queue.sh --plain | grep gpu | wc -l         # count GPU jobs
./examples/06-process-monitor.sh --mock                      # no real ps needed
```

### Concept map

Where each topic is taught (example → worksheet):

| Topic | Examples | Worksheet |
|---|---|---|
| A. Variables, quoting, expansion | 01, 02 | 01 |
| B. stdout, stderr, redirection, here-docs | 05, 08 | 02 |
| C. Pipes, `&&`, `\|\|`, `pipefail` | 05, 06, 08 | 02 |
| D. Tests and conditionals | 03, 04, 05 | 03 |
| E. Loops and arithmetic, `read` | 02, 04 | 03 |
| F. Functions, arguments, scope | 03, 07 | 05 |
| G. Arrays | 04, 07, 08 | 05 |
| H. Text processing tools | 05, 08 | 04 |
| I. Files and filesystem | 05 | 04 |
| J. Processes, timing, cleanup | 06, 07, spinner | 06 |
| K. Shell safety and debugging | all | 01, 06 |

## The graphics API

Source the framework, then draw. Coordinates are **1-based columns and rows**,
with `(1, 1)` at the top-left. Anything off screen is clipped; later drawing
covers earlier drawing.

```bash
source ./tui.sh           # defines functions only; nothing is drawn yet
```

| Function | Description |
|---|---|
| `clear [color]` | Reset the virtual screen to blank cells with an optional background. |
| `rect x y width height color [char]` | Filled rectangle. |
| `line x1 y1 x2 y2 color [char]` | Straight line (Bresenham). |
| `circle center_x center_y radius color [char]` | Filled circle, stretched 2:1 so it looks round in terminal cells. |
| `text x y string [color [background]]` | One line of text. Keeps the existing background unless one is given. |
| `set_color foreground [background]` | Print a color escape *directly* to the terminal (for non-TUI scripts). |
| `move_cursor x y` | Move the real cursor *directly* (for non-TUI scripts). |
| `run_app` | Start the lifecycle loop (see below). |

**Shapes are solid by default**: cells are painted with `color` as their
background. Pass `char` to draw that character in `color` instead:

```bash
rect 2 2 10 3 blue          # solid blue block
rect 2 6 10 3 yellow '#'    # yellow ##### characters
```

**Colors**: `black red green yellow blue magenta cyan white`, the `bright_`
version of each (`bright_red`), `gray`, `default`, or a number `0`–`255`.

**Errors**: bad arguments print a usage message on stderr and return status
`2` — nothing is drawn, nothing crashes:

```bash
rect 1 one 5 5 red || echo "rect failed with status $?"
```

**Helpers** (also in the framework): `fb_init w h` (allocate a virtual screen
of a fixed size), `fb_dump` (print the virtual screen as plain text — great for
debugging), `fb_cell x y` (sets `CELL_CH`, `CELL_FG`, `CELL_BG`), `is_int`,
`is_uint`, `clamp`, `random_int`, `repeat_char`, `color_code`, `tui_warn`,
`quit`.

> **`REPLY` convention.** Helpers that produce a value store it in `$REPLY`
> (the same variable `read` uses) instead of printing it, which avoids a
> slow `$(...)` subshell every frame. Copy it right away —
> `random_int 1 6; roll=$REPLY` — because the next helper call overwrites it.

> **`clear` is a framework function** once `tui.sh` is sourced. Run
> `command clear` if you ever need the real `clear` program.

Try the API without starting an app:

```bash
bash -c 'source ./tui.sh; fb_init 24 6; rect 2 2 6 3 red "#"; circle 16 3 2 blue o; text 3 6 "hello"; fb_dump'
```

## Writing an app

Define any of these optional hooks, then call `run_app`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/tui.sh"

setup()   { x=1; }                               # once, before the first frame
update()  { x=$(( x % SCREEN_WIDTH + 1 )); }     # every frame: change state
draw()    { text "$x" 5 "hello" bright_green; }  # every frame: draw the scene
on_key()  { [[ $1 == SPACE ]] && x=1; return 0; } # a key: letters, UP, DOWN, LEFT, RIGHT, ENTER, SPACE, ESC
cleanup() { :; }                                 # once, on any exit (q, Ctrl+C, error)

run_app
```

Each frame `run_app` calls `update`, then **`clear`**, then `draw`, then
renders. Because the screen is cleared before every `draw`, you always draw the
complete scene in back-to-front order — background effects first, panels and
text last. **q** always quits; other keys go to `on_key`. `on_resize` is called
after the terminal changes size.

| Setting | Default | Meaning |
|---|---|---|
| `TUI_FPS` | 15 | Frames per second. |
| `TUI_FRAMES` | 0 | Stop after N frames (0 = until **q**). Used by the tests. |
| `TUI_WIDTH`, `TUI_HEIGHT` | terminal size | Force a screen size. |

Inside hooks you can read `SCREEN_WIDTH`, `SCREEN_HEIGHT` and `TUI_FRAME` (the
frame counter, starting at 1). Call `quit` to stop after the current frame.

`run_app` installs `trap` handlers for `EXIT`, `INT` (Ctrl+C), `TERM` and
`HUP`; whichever way the script ends, your `cleanup` runs once and the terminal
gets its colors, cursor, line wrapping and normal screen back.

## Effects

Effects are reusable components that follow one convention:

| Function | Call it from | Does |
|---|---|---|
| `<name>_init` | `setup` (and `on_resize`) | create state |
| `<name>_update` | `update` | advance one frame |
| `<name>_draw` | `draw` | write into the virtual screen |

Effects never print or clear the terminal themselves, so they combine with
your own drawing just by ordering calls in `draw`:

```bash
setup()  { matrix_init; spinner_init; sleep 5 & spinner_add 3 3 "Copying" "$!"; }
update() { matrix_update; spinner_update; }
draw()   {
    clear black
    matrix_draw                     # 1. background
    rect 2 2 30 3 black             # 2. a panel that hides the rain
    spinner_draw                    # 3. foreground
}
```

- **Matrix rain** (`lib/effects/matrix.sh`): set `MATRIX_COLOR`,
  `MATRIX_HEAD_COLOR` or `MATRIX_SPACING` before `matrix_init`.
- **Spinner** (`lib/effects/spinner.sh`): `spinner_add x y label [pid]` spins
  while the process `pid` runs, then shows `OK` or its exit status.

To write a new effect, copy `spinner.sh`, rename the functions and add a
`source` line to `tui.sh` (or source it from your own script).

## How the renderer works

1. **Virtual screen.** Each row is three strings of `SCREEN_WIDTH`
   characters: the characters, a one-character color id per cell for the text
   color, and one for the background. Drawing a shape replaces a span of
   those strings — fast, because Bash does the string work internally.
2. **Diff.** `render` compares each row with what it drew last frame.
   Identical rows cost one comparison and send nothing. For a changed row it
   finds the first and last differing cell (by binary search over prefixes and
   suffixes) and sends only that span.
3. **Batch.** Within the span it emits a color code only where the color
   changes, and the whole frame is written with a single `printf`.
4. **No full clears.** The terminal is cleared once at start-up (and after a
   resize). Never clearing on each frame is what keeps the display from
   flickering.

Limitations, on purpose: one character per cell, so wide characters (CJK,
emoji) and combining accents misalign; no mouse input; Bash is slow, so very
large terminals or thousands of shapes per frame will lower the frame rate.

## Testing

```bash
bash tests/run_all.sh
```

This runs `bash -n` on every script, the unit tests for the framebuffer,
shapes, clipping, colors, renderer and utilities, a short smoke run of every
example with `TUI_FRAMES=3`, and a check that a signal restores the terminal.
Individual test files can be run alone, e.g. `bash tests/drawing.sh`.

Debugging your own scripts:

```bash
bash -n myscript.sh                       # syntax check without running
bash -x examples/05-log-filter.sh data/sample.log 2>trace.txt   # trace every command
TUI_FRAMES=1 bash -x ./myapp.sh 2>trace.txt   # trace one frame of a TUI app
```

(Send TUI traces to a file: tracing to the screen would scribble over the app.)

## Troubleshooting

| Symptom | Fix |
|---|---|
| `$'\r': command not found` | The file has Windows line endings: `sed -i 's/\r$//' file.sh`. |
| `Permission denied` running `./examples/...` | `chmod +x examples/*.sh`, or run with `bash examples/...`. |
| `tui.sh needs Bash 4 or newer` | Install a newer Bash (macOS: `brew install bash`). |
| Terminal looks broken after a crash | Type `reset` and press Enter. |
| Boxes or `?` instead of katakana | Use a UTF-8 locale (`export LANG=C.UTF-8`) or ignore — ASCII is used otherwise. |
| Choppy animation | Make the terminal smaller or lower `TUI_FPS`. |
