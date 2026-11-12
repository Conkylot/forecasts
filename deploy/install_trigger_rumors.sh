#!/usr/bin/env bash
# Run on your Mac. Installs a cron job on the rumors host that starts the
# "Forecast on new AI tournament questions" workflow every 20 minutes through the
# GitHub API, because GitHub's own schedule fires only every few hours.
#
# Usage: bash deploy/install_trigger_rumors.sh [ssh-host-alias]   (default: rumors)
# Needs a fine-grained GitHub token: repository access = forecasts only,
# repository permissions = Actions: Read and write (nothing else).
# Re-running it replaces the token and the cron line; nothing is duplicated.
# To remove: ssh rumors 'crontab -l | grep -v forecasts-trigger | crontab -; rm -rf ~/.forecasts-trigger'
set -euo pipefail
HOST="${1:-rumors}"

read -r -s -p "GitHub token for the forecasts trigger: " TOKEN; echo
[ -n "$TOKEN" ] || { echo "No token entered, nothing changed."; exit 1; }

# 1) Token goes over stdin, never on a command line or into shell history.
printf '%s\n' "$TOKEN" | ssh "$HOST" 'set -e; umask 077; mkdir -p ~/.forecasts-trigger; cat > ~/.forecasts-trigger/token'

# 2) Trigger script + cron line, then one immediate test call.
ssh "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
command -v curl >/dev/null || { echo "curl is not installed on this host"; exit 1; }
D="$HOME/.forecasts-trigger"
cat > "$D/trigger.sh" <<'SH'
#!/bin/sh
D="$HOME/.forecasts-trigger"
T=$(cat "$D/token")
code=$(curl -sS -m 30 -o /dev/null -w '%{http_code}' -X POST \
  -H "Authorization: Bearer $T" -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/Conkylot/forecasts/actions/workflows/run_bot_on_tournament.yaml/dispatches \
  -d '{"ref":"main"}' 2>&1) || code="curl-error"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $code" >> "$D/trigger.log"
tail -n 1000 "$D/trigger.log" > "$D/trigger.log.tmp" && mv "$D/trigger.log.tmp" "$D/trigger.log"
echo "$code"
SH
chmod 700 "$D/trigger.sh"
( crontab -l 2>/dev/null | grep -v 'forecasts-trigger' || true
  echo "4,24,44 * * * * $D/trigger.sh >/dev/null 2>&1 # forecasts-trigger" ) | crontab -
echo "cron installed:"; crontab -l | grep forecasts-trigger
echo -n "test call (expect 204): "; "$D/trigger.sh"
REMOTE
