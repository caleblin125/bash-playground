# 04 — Text processing and files

**Examples:** `examples/05-log-filter.sh`, `examples/08-job-queue.sh`
**You will learn:** `grep`, `sed`, `awk`, `cut`, `sort`, `uniq`, `wc`, `tr`,
`head`, `tail`, `printf`, `column`; plus everyday file commands, `find`,
`mktemp` and permissions.

## 1. Run it

```bash
./examples/08-job-queue.sh                         # a/r/p/c/f filter, q quits
./examples/08-job-queue.sh --plain
./examples/08-job-queue.sh --plain --user alice
./examples/08-job-queue.sh --plain | grep -c gpu
./examples/05-log-filter.sh -l ERROR data/sample.log
```

## 2. Concepts

### The tools, one line each

Try each of these on the mock data:

```bash
grep RUNNING data/jobs.txt                 # lines containing a pattern
grep -v RUNNING data/jobs.txt              # lines NOT containing it
grep -c FAILED data/jobs.txt               # count matching lines
sed 's/RUNNING/running/' data/jobs.txt     # substitute (first match per line)
sed -n '2,4p' data/jobs.txt                # print only lines 2-4
awk '{ print $1, $5 }' data/jobs.txt       # fields 1 and 5 (split on spaces)
awk '$7 > 2 { print $4 }' data/jobs.txt    # names of jobs using > 2 nodes
cut -c1-20 data/jobs.txt                   # characters 1-20 of each line
cut -d: -f1,7 /etc/passwd                  # fields 1 and 7, ':' delimited
sort -k2,2 data/jobs.txt                   # sort by field 2
awk '{ print $2 }' data/jobs.txt | sort | uniq -c | sort -rn   # jobs per user
wc -l data/*.txt                           # line counts
tr 'a-z' 'A-Z' < data/nodes.txt            # translate characters
head -n 3 data/jobs.txt; tail -n 2 data/jobs.txt
column -t data/nodes.txt                   # optional: align columns (util-linux)
```

`uniq` only merges **adjacent** duplicates, which is why it almost always comes
after `sort`.

### Shell syntax vs tool syntax

`sed` and `awk` are separate programs with their own little languages. The
shell only passes them a string. **Put that string in single quotes** so the
shell leaves it alone:

```bash
awk '$5 == "FAILED" { print $1 }' data/jobs.txt     # awk's $5 = field 5
```

In double quotes the shell would replace `$5` with *its* fifth argument
(usually empty) before awk ever ran. To give awk a shell value, pass it as a
variable with `-v`:

```bash
state=PENDING
awk -v s="$state" '$5 == s { print $1, $2 }' data/jobs.txt
```

The same separation applies to regular expressions: `grep -E 'WARN|ERROR'`
is a regex for grep, not shell syntax.

### Formatting output

```bash
printf '%-8s %-10s %5s\n' JOB STATE NODES
awk 'NR > 1 { printf "%-8s %-10s %5d\n", $1, $5, $7 }' data/jobs.txt
```

### Files and directories

```bash
pwd                          # where am I? (absolute path)
mkdir -p results/run1        # -p: create parents, no error if it exists
cp data/jobs.txt results/run1/
mv results/run1 results/run-001
ls -l results/run-001
find . -name '*.sh' -newer README.md     # files matching a pattern
find data -type f -size -2k              # small regular files
rm results/run-001/jobs.txt              # removes for good: there is no trash
```

**Be careful with `rm`.** Always check a path before deleting, never build
`rm -rf "$dir/"*` from a variable that might be empty, and prefer deleting
specific files you created. Use `ls` on the same pattern first.

**Temporary files** should come from `mktemp`, which creates a unique file
and prints its name; clean up with a trap:

```bash
tmp=$(mktemp)
trap 'rm -f -- "$tmp"' EXIT
sort data/jobs.txt > "$tmp"
```

**Permissions**: `ls -l` shows `rwx` for user, group, others.
`chmod +x script.sh` lets it run as `./script.sh`; `chmod 600 secrets.txt`
makes a file readable only by you.

## 3. Modification challenge — scheduler output to a colored table

Write `job-table.sh` that turns `data/jobs.txt` (or a file given as `$1`) into
a colored status table. Required:

1. Skip the header line. Print your own header in bold.
2. Columns: job id, user, name, state, nodes — aligned with `printf` or awk's
   `printf`.
3. Color the state: RUNNING green, PENDING yellow, FAILED red, COMPLETED blue.
   Only use colors when stdout is a terminal (`[[ -t 1 ]]`).
4. Finish with a summary line such as `4 running, 4 pending, 2 failed,
   2 completed` built with `sort | uniq -c` or an awk associative array.
5. A missing file prints an error on **stderr** and exits `2`; an empty file
   prints `no jobs` and exits `0`.

Check: `./job-table.sh | cat` must show no escape codes.

## 4. Extension

- Add `--sort nodes` to sort by node count, largest first (`sort -k7,7nr`).
- Print total node-hours used by each user. `TIME` is `HH:MM:SS`; in awk,
  `split($6, t, ":")` gives you the parts.
- Use `find data -name '*.txt'` to run your table over every data file whose
  first line starts with `JOBID`.

## 5. Debugging prompt

This one-liner should list failed job ids but prints every line of the file,
and the `sed` command fails with `unknown option to s`. Why?

```bash
awk "\$5 == \"FAILED\" { print $1 }" data/jobs.txt
dir=/scratch/alice
sed "s/HOME/$dir/" template.txt
```

<details><summary>Hints</summary>

- In double quotes the shell expands `$1` (empty), so awk sees `{ print }`,
  which prints the whole line. Use single quotes: `awk '$5 == "FAILED" { print $1 }'`.
- After expansion the sed script is `s/HOME//scratch/alice/`: the slashes in
  the value end the expression early. Use another delimiter: `sed "s|HOME|$dir|"`.
</details>
