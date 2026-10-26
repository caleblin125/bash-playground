# 01 — Variables, quoting and expansion

**Examples:** `examples/01-banner.sh`, `examples/02-progress.sh`
**You will learn:** variables, single vs double quotes, command substitution,
arithmetic expansion, environment variables, and how to make a script
executable and check it for mistakes.

## 1. Run it

```bash
cd bash-playground
./examples/01-banner.sh
./examples/01-banner.sh "HPC Club Workshop"
bash examples/01-banner.sh          # works even without the executable bit
```

## 2. Concepts

### Making and running a script

The first line, `#!/usr/bin/env bash`, is the *shebang*: it tells the system
which program runs the file. `env` finds `bash` on your `PATH`, which is more
portable than hard-coding `/bin/bash`.

```bash
chmod +x examples/01-banner.sh   # allow it to be executed
./examples/01-banner.sh          # relative path: from the current directory
"$PWD/examples/01-banner.sh"     # absolute path: works from anywhere
bash -n examples/01-banner.sh    # syntax check only, runs nothing
bash -x examples/01-banner.sh    # trace: print each command before running it
```

### Variables and expansion

```bash
name=Ada                 # no spaces around =
greeting="Hello, $name"  # double quotes: $variables are expanded
literal='Hello, $name'   # single quotes: nothing is expanded
printf '%s\n' "$greeting" "$literal"
```

`name = Ada` (with spaces) is a different thing entirely: it runs a *command*
called `name` with arguments `=` and `Ada`.

### Command substitution and arithmetic

```bash
host=$(hostname)                 # run a command, capture its output
printf 'Running on %s\n' "$host"
files=$(ls | wc -l)
x=41
printf 'x+1 = %d\n' "$(( x + 1 ))"   # integer arithmetic; no $ needed inside
```

### Environment variables

Some variables are set for every program you run:

```bash
printf 'HOME=%s\nTERM=%s\n' "$HOME" "$TERM"
printf '%s\n' "$PATH" | tr ':' '\n'     # the directories searched for commands
env | sort | head                       # list all of them
GREETING=hi bash -c 'echo "$GREETING"'   # set one just for one command
```

### Why quoting matters

Without quotes, the shell splits a variable's value on spaces and expands
glob characters such as `*`:

```bash
title='My * Project'
printf '[%s]\n' $title       # unquoted: split into words, * becomes file names!
printf '[%s]\n' "$title"     # quoted: exactly one argument, unchanged
```

**Rule of thumb:** always write `"$var"` and `"$(command)"` unless you have a
specific reason not to.

### printf vs echo

`printf 'format' args...` behaves the same everywhere and lets you pad and
align: `%-10s` (left-aligned, 10 wide), `%5d`, `%3d%%`. `echo` varies between
systems when given `-n`, `-e` or backslashes. The examples use `printf`.

### Colors are just bytes

`\e[31m` switches the terminal to red, `\e[0m` resets it. `printf '%b'`
expands such escapes inside an argument:

```bash
printf '\e[1;33m%s\e[0m\n' "bold yellow"
```

## 3. Modification challenge

Edit `examples/01-banner.sh` (make a copy first: `cp examples/01-banner.sh my-banner.sh`):

1. Add a line showing the number of CPU cores: `nproc` (or `getconf _NPROCESSORS_ONLN`).
2. Add a line with the system uptime from `uptime -p`. If that fails, print `unknown`
   instead (hint: `value=$(cmd 2>/dev/null) || value=unknown`).
3. Let an environment variable choose the title color:
   `BANNER_COLOR=32 ./my-banner.sh` → green. Default to cyan (`36`) when unset
   (hint: `${BANNER_COLOR:-36}`).

## 4. Extension

Draw a full box around the title using `+`, `-` and `|`, sized to fit the
title exactly whatever its length. Then center the box in the terminal using
`$COLUMNS` (run `shopt -s checkwinsize` or use `tput cols`).

## 5. Debugging prompt

A teammate wrote this. Run it with the title below and explain each problem.
Use `bash -x` to watch what the shell actually does.

```bash
#!/usr/bin/env bash
title = $1
host='$(hostname)'
printf "Welcome to %s on %s\n" $title $host
```

```bash
./broken.sh "Cluster * Status"
```

<details><summary>Hints</summary>

- `title = $1` runs a command called `title`. Remove the spaces.
- `'$(hostname)'` is in single quotes, so it is the literal text, not the output.
- `$title` unquoted is split into several words and `*` expands to file names,
  so printf receives far too many arguments. Quote both variables.
</details>
