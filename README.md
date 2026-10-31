# claude-code-no-agent-summary

A Bun `--preload` hook that turns off the `agent_summary` side query of Claude Code.

This is our maintained copy of the hook by Flamerix AI. We keep it here so that we do not depend on the
upstream gist.

## Problem

When a subagent or a background agent runs, Claude Code arms a timer. About every 30 seconds, the timer
sends the full transcript of the agent to the agent's model. The request asks for a 3 to 5 word status.
The answer only updates the status line in the agents panel. No setting turns this off.

## How the hook works

1. The hook wraps the global `setTimeout`.
2. For each timer callback, it reads the source text with `Function.prototype.toString`.
3. When the source contains `[AgentSummary] Timer fired` or `agent_summary`, it returns a timer that
   never fires.
4. All other timers pass through without change.

The hook installs only inside Claude Code (`Bun.main` and `process.execPath` checks). Other `bun`
processes load the file and do nothing. The Claude Code binary is not modified.

## Install

1. Clone this repository to a stable path.
2. Add this line to `~/.zshrc`. Use the `=` form: the space form breaks `bun` subcommands.

   ```sh
   export BUN_OPTIONS="${BUN_OPTIONS:+$BUN_OPTIONS }--preload=$HOME/Documents/Github/claude-code-no-agent-summary/no-agent-summary.js"
   ```

3. Stop the daemon, so that new background sessions get the variable:

   ```sh
   claude daemon stop --any
   ```

4. Restart every running Claude Code session from a new shell.

## Verify

Warning: a Claude Code update can stop the hook without an error. Run the check after every update.

```sh
scripts/verify.sh
```

The script runs one headless task three times: no hook, `pass` mode and `off` mode. Expected result: summary
forks > 0 without the hook and in `pass` mode, and 0 in `off` mode.

Quick load check, without model calls:

```sh
CC_AGENT_SUMMARY_LOG=/tmp/nas.log claude --version && cat /tmp/nas.log
```

Expected: a `preload active mode=off` line.

## Environment variables

| Variable | Values | Effect |
|---|---|---|
| `CC_AGENT_SUMMARY_MODE` | `off` (default), `pass` | `off` suppresses the summary timer. `pass` arms every timer (A/B control). |
| `CC_AGENT_SUMMARY_LOG` | file path | Appends load, match and exit lines. |
| `CC_AGENT_SUMMARY_MARKER` | file path | Overwritten with the `preload active` line on load. |

## When the check fails

The hook matches by source text. It fails open when an update:

- renames the log line or the query source id;
- passes the callback through `fn.bind(...)` or another wrapper;
- moves the strings out of the callback;
- moves the timer off the global `setTimeout`.

To fix it:

1. Find the new summary strings in the binary, for example with
   `grep -aoF 'AgentSummary' ~/.local/share/claude/versions/<version>`.
2. Update `ANCHORS` in `no-agent-summary.js`.
3. Run `scripts/verify.sh`.
4. Record the result in the table below.

To turn the hook off, remove the `BUN_OPTIONS` line from `~/.zshrc` and run `claude daemon stop --any`.

## Visible effect

The status line of each agent in the agents panel does not update. Subagents and background agents run
normally.

## Tested versions

| Date | Claude Code | Platform | No hook / `pass` / `off` |
|---|---|---|---|
| 2026-10-31 | 2.1.316 (native installer) | macOS arm64, bun 1.4.4 | 6 / 5 / 0 |

## Provenance

- Upstream: https://gist.github.com/flamerix-ai/c3905705cc4205e5de3011fa2e74efce
- Imported revision: `4f1ad563fbe4fb830af5dd67fbde4c1860f9caa6` (hook v3), without changes.
- License: MIT. Keep the Flamerix AI copyright notice in `LICENSE` and in the file header.

This project is not affiliated with Anthropic. The hook changes the runtime behaviour of the client. Check
the terms of service that apply to you.
