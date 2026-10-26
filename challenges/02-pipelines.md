# 02 — Redirection, pipes and exit status

**Examples:** `examples/05-log-filter.sh`, `examples/06-process-monitor.sh`
**You will learn:** standard input/output/error, redirection, pipelines,
`&&` / `||`, exit status, and `set -o pipefail`.

## 1. Run it

```bash
./examples/05-log-filter.sh data/sample.log
echo "exit status: $?"
cat data/sample.log | ./examples/05-log-filter.sh
./examples/06-process-monitor.sh            # live; q quits, s changes sort
```

## 2. Concepts

### Three standard streams

Every program starts with three open streams:

| Stream | Number | Default | Use it for |
|---|---|---|---|
| standard input | 0 | keyboard | data coming in |
| standard output | 1 | terminal | **results** |
| standard error | 2 | terminal | **messages, warnings, errors** |

Keeping results on stdout and messages on stderr means a pipeline only
receives data, while humans still see the messages.

### Redirection

```bash
printf 'job started\n' >> jobs.log       # append to a file (create if missing)
grep 'FAILED' jobs.log > failures.txt    # overwrite a file with the output
wc -l < jobs.log                         # read stdin from a file
ls /nonexistent 2> errors.txt            # send stderr to a file
ls /nonexistent 2>/dev/null              # throw stderr away
make > build.log 2>&1                    # both streams into one file
printf 'oops\n' >&2                      # write to stderr from a script
```

Order matters: `cmd > file 2>&1` sends both to the file, but
`cmd 2>&1 > file` sends stderr to the *terminal* (it copied stdout's old target
before stdout was redirected).

A **here-document** feeds several lines to a command's stdin:

```bash
cat <<EOF > notes.txt
Host: $(hostname)
User: $USER
EOF
```

Use `<<'EOF'` (quoted) to stop `$` expansion inside it.

### Printing vs exit status

Printing is how a program *talks*; the exit status (`0` = success, anything
else = failure) is how it *reports success*. They are independent:

```bash
grep -q ERROR data/sample.log     # prints nothing at all...
echo $?                           # ...but the status is 0: a match was found
```

`./examples/05-log-filter.sh` prints a report *and* exits `1` when errors
exist, so other scripts can react to it without parsing the text.

### Pipes and command lists

```bash
ps -eo comm,%cpu --sort=-%cpu |
    head -n 6 |
    awk 'NR > 1 { printf "%-20s %6s%%\n", $1, $2 }'
```

`a | b` connects a's stdout to b's stdin; both run at the same time.

| Syntax | Runs the second command… |
|---|---|
| `a ; b` (or a newline) | always |
| `a && b` | only if `a` **succeeded** (status 0) |
| `a \|\| b` | only if `a` **failed** (status ≠ 0) |

```bash
mkdir -p results && cd results
grep -q FAILED jobs.log || printf 'no failures\n'
```

`&&` and `||` look only at the exit status — never at what was printed.
`grep` prints nothing with `-q` but still drives `&&` correctly.

### Pipeline status and pipefail

A pipeline's status is normally that of its **last** command, so failures
earlier in the pipeline are hidden:

```bash
cat missing.txt | sort ; echo "status $?"          # 0: sort succeeded
set -o pipefail
cat missing.txt | sort ; echo "status $?"          # 1: cat's failure counts
```

The examples start with `set -euo pipefail`; challenge 06 explains its limits.

## 3. Modification challenge

Start from the process pipeline (on a machine without `ps -eo`, replace the
first command with `tail -n +2 data/ps-sample.txt`):

```bash
ps -eo comm,%cpu --sort=-%cpu | head -n 6 | awk 'NR > 1 { printf "%-20s %6s%%\n", $1, $2 }'
```

1. **Filter**: show only processes whose name contains `bash` (add `grep`, or
   use an awk condition like `$1 ~ /bash/`).
2. **Count**: print how many `bash` processes there are (`grep -c`, or `wc -l`).
3. **Empty result**: search for a name that does not exist. Make the pipeline
   print `none found` instead of nothing (hint: capture the output in a
   variable and test it with `[[ -z $out ]]`, or use `grep ... || echo`).
4. In `examples/06-process-monitor.sh`, change the number of rows shown from
   15 to 10 and add a fifth column for the process's user (`ps -eo user,...`).

### stdout vs stderr challenge

Write `node-report.sh` that reads `data/nodes.txt` and:

- prints **only** `name state` pairs for non-RUNNING nodes on **stdout**, one per line;
- prints progress messages such as `reading data/nodes.txt...` on **stderr**;
- exits `1` if any node is `FAILED`, else `0`.

It is correct when all of these behave:

```bash
./node-report.sh                         # you see both messages and data
./node-report.sh 2>/dev/null             # only data
./node-report.sh > report.txt            # only messages on screen; data in the file
./node-report.sh | wc -l                 # counts data lines only
./node-report.sh >/dev/null 2>&1 || echo "a node has failed"
```

## 4. Extension

Make `05-log-filter.sh` accept several files (`"$@"`) and print the file name
before each section. A missing file should produce an error on stderr but not
stop the other files from being processed; the final exit status should be 2
if any file was missing.

## 5. Debugging prompt

This script is meant to warn when an `mpirun` process is running. It always
says something is running, and its log file never contains the error messages.
Why?

```bash
#!/usr/bin/env bash
count=$(ps aux | grep mpirun | wc -l)
if [[ $count -gt 0 ]]; then
    echo "mpirun is running ($count processes)"
fi
./check-nodes.sh 2>&1 > check.log
```

<details><summary>Hints</summary>

- The `grep mpirun` process itself appears in `ps aux` output, so the count is
  never 0. Use `pgrep -c mpirun`, or `grep '[m]pirun'`, or `ps -C mpirun`.
- `2>&1 > check.log` duplicates stderr onto the terminal *before* stdout moves
  to the file. Swap them: `> check.log 2>&1`.
</details>
