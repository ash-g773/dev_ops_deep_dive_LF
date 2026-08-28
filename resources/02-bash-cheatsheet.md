# Bash Cheatsheet

Everything from the session, in one place. **You already program** — so this is what bash's version looks like, and where the syntax is strange.

---

## 1. Running a script

```bash
#!/bin/bash
# hello — my first script

echo "Hello, $USER!"
```

```bash
chmod +x hello      # make it executable
./hello             # run it
```

- **`#!/bin/bash` must be line one.** No blank lines above it. It tells the OS which program interprets the file
- **`chmod +x`** adds execute permission. Without it you get `Permission denied`
- **`./`** means "the file is here" — your current folder isn't on the `PATH`

### Making it a real command

```bash
mkdir -p ~/bin
mv hello ~/bin/hello          # note: no .sh extension
export PATH="$HOME/bin:$PATH"

hello                         # now works from anywhere
```

Add the `export` line to `~/.bashrc` (or `~/.zshrc` on macOS) to make it permanent.

> The `.sh` extension means **nothing** to Linux — the shebang decides how a file runs. That's why `git` and `docker` have no extension.

---

## 2. Variables and quoting

```bash
name="Alice"          # assign — NO SPACES around the =
echo "$name"          # read — needs the $
```

`name = "Alice"` is an error. Bash reads `name` as a command to run.

### Braces

```bash
resource="countries"

echo "$resource.js"        # fine
echo "$resource_api"       # BROKEN — looks for a variable called resource_api
echo "${resource}_api"     # correct
```

Use `${braces}` whenever the variable is followed by a letter, digit or underscore.

### Default values

```bash
name="${1:-World}"              # use $1, or "World" if it's missing
model="${2:-${resource^}}"      # use $2, or capitalised $resource
```

`${var:-default}` is bash's version of `??` or a default parameter. `${var^}` capitalises the first letter.

### Quoting — the thing that causes most bugs

| Quoting | Behaviour |
|---|---|
| `"double"` | expands `$variables` and `$(commands)` |
| `'single'` | **completely literal** — nothing expands |
| none | expands, **then splits on spaces** |

```bash
file="my report.txt"

rm $file            # tries to delete "my" AND "report.txt"
rm "$file"          # correct
```

> **Quote your variables.** `"$var"`, `"$1"`, `"$@"`. Unless you have a specific reason not to.

### Useful built-ins

`$USER` · `$HOME` · `$PWD` · `$PATH` · `$HOSTNAME`

---

## 3. Command substitution and arithmetic

```bash
echo "Backup ran at $(date)"
files=$(ls | wc -l)
```

`$( )` runs a command and drops its **output** in place.

Bash won't do maths unless you ask:

```bash
echo $(( 10 + 3 ))        # 13
echo $(( 10 / 3 ))        # 3 — integer division, no floats
count=$(( count + 1 ))
```

Sequences:

```bash
echo {1..5}               # 1 2 3 4 5
seq 10 -1 6               # 10 9 8 7 6 — a step of -1 counts DOWN
```

---

## 4. Getting input in

### Arguments

```bash
./greet Alice Bob
```

| | Holds |
|---|---|
| `$1` `$2` `$3` | first, second, third argument |
| `$@` | all of them |
| `$#` | how many |
| `$0` | the script's own name |

A **space separates arguments** — `./greet DevOps Engineer` is two. Quote it to pass one.

### Interactive

```bash
read -p "What's your name? " name
echo "Hello, $name"
```

> **Never use `read` in a script a pipeline will run.** There's no human to answer, so the job hangs. Same reason you see `apt-get install -y`.

---

## 5. Exit codes

Every command returns a number. **`0` is success. Anything else is failure.**

```bash
ls /nonexistent
echo $?              # 2 — that failed

ls ~
echo $?              # 0 — success
```

Your script reports its own status:

```bash
if [ -z "$1" ]; then
  echo "Usage: myscript <name>" >&2
  exit 1
fi
```

`>&2` sends the message to **standard error** rather than normal output — so automated tools can tell your results apart from your complaints.

### Why it matters

Exit codes are the **contract** between your script and anything that runs it automatically. A pipeline decides pass or fail by reading them. A script that swallows an error and exits `0` makes a broken build look green.

### Chaining

```bash
mkdir app && cd app              # cd only if mkdir SUCCEEDED
cd app || echo "no such folder"  # echo only if cd FAILED
command_a ; command_b            # run b regardless
```

> `&&` rather than `;` is a real safety feature. `mkdir app ; cd app` will happily `cd` into the **wrong directory** if the `mkdir` failed.

### Fail fast

```bash
set -e      # exit immediately if any command fails
```

Put it at the top of any script that does real work.

---

## 6. Conditionals

```bash
if [ CONDITION ]; then
  # commands
else
  # commands
fi
```

- `then` must be separated from the condition — hence the `;`
- `fi` closes it. It's "if" backwards

### The spaces are not optional

`[` is **a command**, not punctuation. Bash splits on spaces to find it.

```bash
if [ -z "$1" ]; then      # correct
if [-z "$1"]; then        # ERROR — bash looks for a command called "[-z"
```

**If your `if` is mysteriously broken, this is why 90% of the time.**

### Test operators

**Is it empty?**

| Test | True when |
|---|---|
| `-z "$var"` | empty (**z**ero length) |
| `-n "$var"` | not empty |

**Does it exist?**

| Test | True when |
|---|---|
| `-f path` | a **file** exists there |
| `-d path` | a **directory** exists there |

**Comparing**

| Strings | Numbers |
|---|---|
| `"$a" = "$b"` | `$a -eq $b` |
| `"$a" != "$b"` | `$a -ne $b` |
| | `$a -lt $b` (less than) |
| | `$a -gt $b` (greater than) |

> **Strings use `=`. Numbers use `-eq`.** Mixing them doesn't always error — it just quietly misbehaves.

`!` negates any test: `[ ! -f "Dockerfile" ]` is "if a Dockerfile does **not** exist".

### The guard clause

The most common real-world `if` — validate input, fail fast:

```bash
#!/bin/bash
if [ -z "$1" ]; then
  echo "Usage: scaffold <resource> [ModelName]" >&2
  exit 1
fi
```

---

## 7. Loops

```bash
for VARIABLE in LIST; do
  # commands
done
```

```bash
for dir in controllers models routers db; do
  mkdir -p "server/$dir"
done
```

- The variable name is yours — **no `$` when you declare it**
- The list is separated by **spaces**
- `done` closes it, the way `fi` closed the `if`

It's `array.forEach()` — invent a variable, iterate a collection, run a block. The difference: **bash lists are just words, not objects.**

### Lists can be generated

```bash
for file in *.js; do          # every .js file here
  echo "Found: $file"
done

for i in {1..5}; do           # numbers
  touch "test$i.txt"
done

for arg in "$@"; do           # every argument
  echo "Got: $arg"
done
```

---

## 8. Functions

```bash
name_of_function() {
  # commands
}
```

```bash
log() {
  echo "[$(date +%H:%M:%S)] $1"
}

log "Starting up"          # [09:41:02] Starting up
log "Creating folders"     # [09:41:02] Creating folders
```

- The name is yours — no `function` keyword needed
- **`()` is always empty.** Bash has no parameter list, ever
- Define a function **before** you call it

### The gotcha

**`$1` inside a function is the function's first argument, not the script's.**

Since nothing declares what a function expects, a comment is the only documentation that will ever exist:

```bash
# log — print a timestamped message
# Takes: $1 = message
log() { echo "[$(date +%H:%M:%S)] $1"; }
```

### `local`

Bash variables are **global by default** — the opposite of what you'd expect.

```bash
countdown() {
  local start="$1"      # stays inside the function
  local stop="$2"
}
```

Use `local` for everything inside a function.

---

## 9. Pipes and redirection

```bash
ls -la > listing.txt        # write (OVERWRITES)
echo "line" >> log.txt      # append
command > /dev/null         # discard output
command 2>/dev/null         # discard errors
```

> `>` versus `>>` catches everyone once. `>` wipes the file first.

### Pipes

```bash
ls /etc | sort | head -10
cat access.log | grep "404" | wc -l
```

| Command | Does |
|---|---|
| `grep "text"` | keep only matching lines |
| `sort` / `sort -r` | alphabetical / reverse |
| `head -5` / `tail -5` | first / last 5 lines |
| `wc -l` | count lines |

### `tee` and sudo

```bash
echo "content" | sudo tee /var/www/html/index.html
```

`sudo echo "x" > /root/file` **fails** — the shell sets up the `>` as *you*, before `sudo` runs. Piping into `sudo tee` means the writing program runs as root.

---

## 10. Heredocs — writing whole files

```bash
cat > server/index.js << 'EOF'
const app = require("./app");
app.listen(3000);
EOF
```

- `cat > file` — redirect the output into this file
- `<< 'EOF'` — "here comes text; read until a line that is just `EOF`"
- The closing marker must be **alone on its line**

### The quoting difference

| Written as | Behaviour | Use when |
|---|---|---|
| `<< 'EOF'` | **literal** — leaves `$` alone | the file has its own `$`, like JS template literals |
| `<< EOF` | bash **substitutes** its variables first | you want `$resource` filled in |

```bash
# Unquoted — $resource IS substituted
cat > app.js << EOF
const router = require("./routers/${resource}");
EOF

# Quoted — nothing substituted, so ${PORT} survives for Node
cat > index.js << 'EOF'
app.listen(PORT, () => console.log(`Listening on ${PORT}`));
EOF
```

> **Quote the marker by default.** An accidental substitution silently corrupts the file rather than erroring.

---

## 11. Gotchas

| Gotcha | Fix |
|---|---|
| `name = "value"` | **No spaces** around `=` |
| `[-z "$1"]` | **Spaces inside brackets** — `[` is a command |
| `rm $file` with a space in the name | **Quote it** — `rm "$file"` |
| `>` when you meant `>>` | `>` overwrites, `>>` appends |
| `"$a" -eq "$b"` on strings | `=` for strings, `-eq` for numbers |
| `$(( 10 / 3 ))` gives `3` | Bash has **no floats** |
| Variable changed inside a function | Use `local` |
| Script hangs forever in CI | An interactive prompt. Remove `read`, add `-y` |
| `sudo echo x > /root/f` fails | `echo x \| sudo tee /root/f` |
| Heredoc mangles `${...}` in generated code | Quote the marker: `<< 'EOF'` |
| `$PATH` change gone in a new terminal | Add the `export` to `~/.bashrc` |

---

## Quick reference

```bash
# --- basics ---
#!/bin/bash                 shebang, line one
chmod +x script             make it runnable
./script                    run it

# --- variables ---
name="value"                assign (no spaces around =)
"$name"   "${name}"         read (quote it)
"${1:-default}"             default value

# --- substitution ---
$(command)                  use a command's output
$(( 1 + 2 ))                arithmetic

# --- input ---
$1  $2  $@  $#  $0          arguments
read -p "prompt " var       interactive

# --- exit codes ---
$?                          last command's exit code
exit 1                      report failure
set -e                      stop on first error
a && b    a || b    a ; b   chaining

# --- conditionals ---
if [ -f "$f" ]; then ... fi
-z  -n  -f  -d              empty, not empty, file, directory
=  !=                       strings
-eq  -ne  -lt  -gt          numbers

# --- loops ---
for x in a b c; do ... done
for i in {1..5}; do ... done

# --- functions ---
name() { local x="$1"; echo "$x"; }

# --- redirection ---
>  >>  |  >&2  > /dev/null

# --- heredocs ---
cat > f << 'EOF'   ...   EOF      literal
cat > f << EOF     ...   EOF      substitutes
```

---

## Debugging

```bash
bash -x script.sh      # print each command as it runs
bash -n script.sh      # syntax check without running

which docker           # where is it on the PATH
type ls                # binary, alias, function or builtin?
file $(which ls)       # what kind of file is it
```
