# 05 — Functions, arguments and arrays

**Examples:** `examples/03-shapes.sh`, `examples/07-matrix-dashboard.sh`,
`lib/effects/spinner.sh`
**You will learn:** defining functions, `$1 $2 $@ $#`, `local`, `return`
status codes, `shift`, how functions hand back values, and indexed arrays.

## 1. Run it

```bash
./examples/03-shapes.sh
./examples/07-matrix-dashboard.sh          # p pauses the rain, q quits
MATRIX_COLOR=magenta ./examples/07-matrix-dashboard.sh
```

Read `draw_house` in `03-shapes.sh` and `panel` / `meter` in
`07-matrix-dashboard.sh`: custom helpers built only from `rect`, `line` and
`text`.

## 2. Concepts

### Functions and positional parameters

A function is a small script inside your script. It gets its own `$1`, `$2`,
…, `$#` (count) and `$@` (all arguments):

```bash
draw_box() {
    if (( $# < 4 )); then
        printf 'usage: draw_box x y width height [color]\n' >&2
        return 2
    fi
    local x=$1 y=$2 width=$3 height=$4 color=${5:-white}
    # ... validate, then call rect / line / text ...
}

draw_box 2 2 20 5 cyan
```

- **`local`** keeps variables inside the function. Without it, `x` would
  overwrite any global `x` — a classic source of animation bugs.
- **`shift`** drops `$1` and moves the rest down, handy for option loops
  (`while (( $# )); do case $1 in ...; esac; shift; done` in `08-job-queue.sh`).
- **`"$@"`** passes all arguments on unchanged, each as its own word:
  `log() { printf '[%s] %s\n' "$(date +%T)" "$*"; }` vs. `wrapper() { real_cmd "$@"; }`.

### return is for status, not data

`return N` sets the exit status (0–255), exactly like a command. It cannot
return text. Three ways to give back a value:

```bash
# 1. print it and capture with $(...)   (simple, but runs a subshell)
area() { printf '%d\n' $(( $1 * $2 )); }
a=$(area 3 4)

# 2. set a global variable              (fast; the framework uses REPLY)
area() { REPLY=$(( $1 * $2 )); }
area 3 4; a=$REPLY

# 3. succeed or fail                    (for yes/no questions)
is_wide() { (( $1 > 40 )); }
if is_wide "$width"; then ...; fi
```

### Indexed arrays

```bash
nodes=(node01 node02 node03)
nodes+=(node04)                         # append
printf '%s\n' "${nodes[0]}"             # first element
printf '%d nodes\n' "${#nodes[@]}"      # length
for node in "${nodes[@]}"; do           # each element
    printf '%s: UNKNOWN\n' "$node"
done
for i in "${!nodes[@]}"; do             # each index
    printf '%d -> %s\n' "$i" "${nodes[i]}"
done
mapfile -t lines < data/nodes.txt       # one element per line of a file
```

**Why `"${array[@]}"`?** Quoted `[@]` expands to exactly one word per
element, even when an element contains spaces. `${array[@]}` unquoted
re-splits elements on spaces, and `"${array[*]}"` joins everything into a
single word:

```bash
names=("Web Content" sshd)
for n in "${names[@]}"; do echo "<$n>"; done    # <Web Content> <sshd>
for n in ${names[@]}; do echo "<$n>"; done      # <Web> <Content> <sshd>
```

**Parallel arrays** (same index = same record) store tables:
`07-matrix-dashboard.sh` keeps `names[i]`, `states[i]` and `loads[i]` for
node *i*; the Matrix effect keeps `MATRIX_X[k]`, `MATRIX_POS[k]`, … for rain
column *k*.

## 3. Modification challenge — a helper you reuse

1. Create `my_helpers.sh` in the repository root containing a function
   `draw_box x y width height [color] [title]` that draws an *outline*
   using `line` with `+`, `-` and `|` characters, and writes the title in the
   top edge. Validate that there are at least four arguments, that the numbers
   are integers (`is_int`), and that width and height are at least 2; otherwise
   print usage on stderr and `return 2`.
2. Use it in **two** different apps:
   - copy `03-shapes.sh` to `my-shapes.sh`, `source` your helper file, and
     frame the scene with `draw_box`;
   - copy `07-matrix-dashboard.sh` and replace `panel` with `draw_box`.
3. Turn the ball in `04-bouncing-ball.sh` into a **particle system**: store
   20 particles in arrays `px py vx vy`, give each a random velocity with
   `random_int -2 2` (remember to copy `$REPLY`), and draw them all with
   different colors taken from a `colors=(...)` array.

## 4. Extension

Write your own effect, `lib/effects/stars.sh`, following the effect
convention: `stars_init` creates random star positions in arrays,
`stars_update` moves them left (wrapping at the edge), `stars_draw` plots
them with `text`. Source it from your app (or from `tui.sh`) and layer it
behind a panel.

## 5. Debugging prompt

Each node should get its own color, but every node is drawn in the same,
wrong color; and `node_label` returns an error instead of a label. Why?

```bash
nodes=("login node" node01 node02)
pick_color() { random_int 1 6; }
node_label() { return "[$1]"; }

draw() {
    local y=2 node
    for node in ${nodes[@]}; do
        pick_color
        text 2 "$y" "$node" white
        text 20 "$y" "$(node_label "$node")" "$REPLY"
        y=$(( y + 1 ))
    done
}
```

<details><summary>Hints</summary>

- `${nodes[@]}` is unquoted, so `"login node"` becomes two loop items.
- `pick_color` puts a number in `REPLY`, but the next call, `text`, overwrites
  `REPLY` before it is used. Copy it at once: `pick_color; color=$REPLY`.
  (`random_int` also returns a number 1–6, which is a 256-color code, not a name.)
- `return` only accepts a numeric status. Print the label with
  `printf '[%s]' "$1"` and capture it with `$(...)`.
</details>
