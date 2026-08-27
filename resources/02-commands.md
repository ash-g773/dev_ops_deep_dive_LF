# Bash Command Reference — Session 2

## Moving around (you already know these)

    pwd                 Print working directory — where am I?
    ls                  List files here
    ls -l               Long format — permissions, size, date
    ls -la              ...including hidden files (those starting with .)
    cd <folder>         Change directory
    cd ~                Go to your home folder
    cd ..               Go up one level

## Looking at files

    cat <file>          Print the whole file
    head -5 <file>      First 5 lines
    tail -5 <file>      Last 5 lines
    less <file>         Scroll through a file (q to quit)
    wc -l <file>        Count the lines

## Finding things

    grep "text" <file>  Show only lines containing "text"
    find . -name "*.js" Find files by name, from here downwards
    which <command>     Where does this command live?
    type <command>      What IS this command? (binary, alias, function)
    file <path>         What kind of file is this?

## Making things

    touch <file>        Create an empty file
    mkdir <folder>      Create a folder
    mkdir -p a/b/c      Create nested folders, no error if they exist
    cp <src> <dest>     Copy
    mv <src> <dest>     Move (or rename)
    rm <file>           Delete a file
    rm -r <folder>      Delete a folder and its contents

## Chaining commands

    a ; b               Run a, THEN b — regardless of whether a worked
    a && b              Run b ONLY IF a succeeded
    a || b              Run b ONLY IF a failed
    a | b               Send a's OUTPUT into b as INPUT
    a > file            Send a's output into a file (OVERWRITES)
    a >> file           Send a's output into a file (APPENDS)
    $(a)                Run a, and use its output right here

## Permissions

    chmod +x <file>     Allow this file to be run as a program
    chmod -x <file>     Remove that permission
    ls -l               Check what permissions a file has

## Script variables

    $1  $2  $3          First, second, third argument
    $@                  All arguments
    $#                  How many arguments
    $0                  The script's own name
    $?                  Exit code of the last command (0 = success)
    $USER  $HOME  $PATH Built-in environment variables

## Where programs live

    /bin                Essential system commands (ls, cp, cat)
    /usr/bin            Most normal user commands (git, grep, python)
    /usr/local/bin      Software you installed yourself
    ~/bin               YOUR personal scripts (we create this today)
    /etc                System configuration files
    /var                Variable data — logs, caches, web files
    /tmp                Temporary files, wiped on reboot