# 03 — Tests, conditionals, loops and arithmetic

**Examples:** `examples/02-progress.sh`, `examples/03-shapes.sh`, `examples/04-bouncing-ball.sh`
**You will learn:** `if`/`elif`/`else`, `[[ ... ]]` tests, numeric comparisons,
`$?`, `for`/`while` loops, `break`/`continue`, arithmetic, and `read`.

## 1. Run it

```bash
./examples/02-progress.sh 40 0.02
./examples/03-shapes.sh                  # q quits
./examples/04-bouncing-ball.sh           # arrows steer, + / - resize, q quits
TUI_FPS=30 ./examples/04-bouncing-ball.sh
```

## 2. Concepts

### if and [[ ... ]]

`if` runs a command and checks its exit status. `[[ ... ]]` is a command whose
status is 0 when the condition is true.

```bash
if [[ -r config.txt ]]; then
    printf 'Configuration is readable\n'
elif [[ -e config.txt ]]; then
    printf 'Configuration exists but is not readable\n' >&2
else
    printf 'Configuration is missing\n' >&2
fi
```

| Test | True when |
|---|---|
| `-f path` | a regular file exists |
| `-d path` | a directory exists |
| `-r path` / `-w` / `-x` | readable / writable / executable |
| `-s path` | file exists and is not empty |
| `-z "$s"` / `-n "$s"` | string is empty / not empty |
| `$a == "$b"` / `!=` | strings equal / differ (unquoted right side is a *pattern*) |
| `$s =~ ^[0-9]+$` | string matches a regular expression |
| `$a -eq $b` `-ne` `-lt` `-le` `-gt` `-ge` | **numeric** comparisons |

For arithmetic, `(( ... ))` is often clearer: `if (( x > max )); then`.

Combine tests with `&&`, `||` and `!` : `[[ -f $f && ! -s $f ]]` (file exists
but is empty).

### $? — the last exit status

`$?` holds the status of the most recent command, so read it *immediately*:

```bash
grep -q FAILED data/jobs.txt
status=$?                 # save it before running anything else
if (( status == 0 )); then echo "failures present"; fi
```

Usually you can test the command directly instead: `if grep -q FAILED data/jobs.txt; then`.

### Loops

```bash
for ((i = 0; i <= 100; i += 10)); do        # C-style counting loop
    printf '\rProgress: %3d%%' "$i"
    sleep 0.1
done
printf '\n'

for file in data/*.txt; do                  # loop over words / file names
    printf '%s has %d lines\n' "$file" "$(wc -l < "$file")"
done

n=0
while (( n < 5 )); do                       # loop while a condition holds
    n=$(( n + 1 ))
    (( n == 2 )) && continue                # skip the rest of this iteration
    (( n == 4 )) && break                   # leave the loop
    echo "n=$n"
done
```

### Reading input

```bash
read -rp 'How many circles? ' count
if [[ ! $count =~ ^[0-9]+$ ]]; then
    printf 'not a number: %s\n' "$count" >&2
    exit 2
fi
```

`-r` keeps backslashes literal; `-p` shows a prompt. Inside a TUI app use the
`on_key` hook instead.

### Validate before arithmetic

Bash evaluates the text inside `$(( ))` as an expression, so a "number" like
`x[$(rm -rf ~)]` would run a command. **Check user input with a regex before
using it in arithmetic** — every framework function does this with `is_int`.

## 3. Modification challenge

1. **Shape validation.** Add this function to `examples/03-shapes.sh` and call
   it from `draw`. It must reject bad input with a message on stderr and
   `return 2`, and draw nothing:

   ```bash
   # safe_rect X Y WIDTH HEIGHT COLOR
   # - all four numbers must be integers (use is_int / is_uint or [[ =~ ]])
   # - width and height must be between 1 and 50
   # - the whole rectangle must fit on screen: 1 <= x and x + width - 1 <= SCREEN_WIDTH,
   #   same for y and SCREEN_HEIGHT
   safe_rect() {
       # your code here
   }
   ```

   Test it with `safe_rect 2 2 5 3 red`, `safe_rect 0 2 5 3 red`,
   `safe_rect 2 2 -5 3 red`, `safe_rect 2 2 five 3 red` and a rectangle
   that runs off the right edge. Check the statuses with `|| echo "status $?"`.

2. **Progress bar.** In `02-progress.sh`, color the percentage red below 34 %,
   yellow below 67 % and green above, using `if`/`elif`/`else`.

3. **Bouncing ball.** In `04-bouncing-ball.sh`, add *gravity*: every frame
   increase `dy` by 1 up to a maximum of 2, and when the ball hits the floor
   make it bounce back up.

## 4. Extension

Ask the user how many balls to animate with `read` *before* calling `run_app`,
validate the answer (1–10), and store each ball's position and velocity in
arrays (`xs`, `ys`, `dxs`, `dys`). Loop over the arrays in `update` and `draw`.

## 5. Debugging prompt

This check is meant to refuse widths larger than 9. Try `./box.sh 5`,
`./box.sh 95`, `./box.sh 100` and `./box.sh` with no argument. `95` is refused
but `100` is accepted, and the last one crashes. Why?

```bash
#!/usr/bin/env bash
set -u
width=$1
if [[ $width > 9 ]]; then
    echo "too wide" >&2
    exit 2
fi
echo "drawing a box $width wide"
```

<details><summary>Hints</summary>

- Inside `[[ ]]`, `>` compares **strings** in dictionary order: `"100"` comes
  before `"9"` because `1` < `9`. For numbers use `-gt` or `(( width > 9 ))`.
- `set -u` makes using an unset variable an error, and `$1` is unset when no
  argument is given. Use `${1:-}` and then validate it with
  `[[ $width =~ ^[0-9]+$ ]]` before comparing.
- Bonus trap: in the older `[ ]` test, `>` is not a comparison at all but a
  **redirection** — `[ $width > 9 ]` creates a file named `9`.
</details>
