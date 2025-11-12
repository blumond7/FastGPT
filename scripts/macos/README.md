# macOS Terminal Command Logging Setup

This folder contains a helper script for macOS (including Apple Silicon machines such as the M3 Pro) that configures the default Terminal app to keep a comprehensive, timestamped log of every command you run. The commands are saved into a dedicated log file so you can review or search them at any time.

## Prerequisites

- macOS with the default `zsh` shell (the default on modern macOS releases).
- Terminal or iTerm2 — any `zsh`-based environment will work.

## Script overview

`setup-command-log.sh` will:

1. Create the folder `~/.config/fastgpt-terminal/` if it does not exist.
2. Ensure a host-specific log file such as `command-log-MyMacBookPro.tsv` exists.
3. Append a guarded configuration block to `~/.zshrc` (creating the file if needed).
4. Configure `zsh` history to retain 500,000 commands, to append instantly, and to share history between sessions.
5. Register `preexec` and `precmd` hooks that record each command with start/end timestamps, working directory, and exit status in a tab-separated format.

## Usage

```bash
/bin/zsh scripts/macos/setup-command-log.sh
```

Run the script from the root of the repository (or copy it elsewhere before running). After executing the script, restart Terminal or run `source ~/.zshrc` to activate the changes.

All commands will then be logged to:

```
~/.config/fastgpt-terminal/command-log-$(hostname).tsv
```

Each log entry looks like this (tab-separated values):

```
2024-04-16T10:15:33-0400    START   /Users/you/projects    git status
2024-04-16T10:15:33-0400    END     /Users/you/projects    0   git status
```

- `START` entries are written immediately before a command runs.
- `END` entries follow the same command and include the exit status (`0` for success).

You can open the log file in any text editor or use commands like `less`, `rg`, or `grep` to search through your history quickly.
