#!/bin/sh
# Live check of the hook against the installed Claude Code.
# Runs the same headless task three times in parallel: no hook, hook in "pass" mode,
# hook in "off" mode. Each run counts "[AgentSummary] Forking" lines in its debug log.
# Uses the haiku model: one run costs a few cents of rate-limit headroom.
# Exit codes: 0 = hook works, 1 = hook does not suppress, 2 = inconclusive.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOOK="$ROOT/no-agent-summary.js"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/nas-verify.XXXXXX")
PROMPT='Use the Agent tool once (general-purpose subagent, not in background). Tell the subagent: "Run the Bash command `sleep 20` eight times, one tool call at a time, then reply with the single word done." Wait for it, then reply with the single word finished.'

echo "claude: $(claude --version)"
echo "work dir: $WORK"

run() { # name, BUN_OPTIONS value, mode
  (
    cd "$WORK" || exit 1
    env -u BUN_OPTIONS ${2:+BUN_OPTIONS="$2"} \
      CC_AGENT_SUMMARY_MODE="$3" CC_AGENT_SUMMARY_LOG="$WORK/$1.hook.log" \
      CLAUDE_CODE_AGENT_PROGRESS_SUMMARIES=1 \
      claude -p "$PROMPT" --model haiku --allowedTools "Bash(sleep:*)" "Agent" \
      --debug-file "$WORK/$1.debug.log" >"$WORK/$1.out" 2>&1
    echo "exit=$?" >>"$WORK/$1.out"
  ) &
}

run nohook "" off
run pass "--preload=$HOOK" pass
run off "--preload=$HOOK" off
wait

count() {
  c=$(grep -c '\[AgentSummary\] Forking' "$WORK/$1.debug.log" 2>/dev/null)
  echo "${c:-0}"
}
N=$(count nohook)
P=$(count pass)
O=$(count off)
printf 'summary forks: no hook=%s  pass=%s  off=%s\n' "$N" "$P" "$O"
grep -h 'preload active' "$WORK"/*.hook.log 2>/dev/null | cut -d' ' -f3-

if [ "$N" -eq 0 ] || [ "$P" -eq 0 ]; then
  echo "INCONCLUSIVE: no summary forks without the hook. Check the logs in $WORK."
  exit 2
fi
if [ "$O" -ne 0 ]; then
  echo "FAIL: the hook did not suppress the summary timer. Update the anchors."
  exit 1
fi
echo "OK: the hook suppresses the summary timer."
