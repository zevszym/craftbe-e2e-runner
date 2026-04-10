#!/bin/bash
set -euo pipefail

# ── This script runs as root. It fixes volume permissions, ──────────
# ── then drops to 'runner' user for the GH Actions runner.  ────────

GITHUB_URL="${GITHUB_URL:?GITHUB_URL is required}"
RUNNER_NAME="${RUNNER_NAME:-craftbe-runner-$(hostname)}"
RUNNER_LABELS="${RUNNER_LABELS:-craftbe,playwright}"

# ── Fix ownership on all mounted volumes ────────────────────────────
# Docker named volumes are created as root. The runner process needs
# write access as 'runner' user.
echo ":: Fixing volume permissions..."
chown -R runner:runner /home/runner/actions-runner/_work 2>/dev/null || true
chown -R runner:runner /home/runner/.npm 2>/dev/null || true

# ── Generate runner token from PAT ──────────────────────────────────
if [ -n "${GITHUB_PAT:-}" ]; then
  OWNER_REPO="${GITHUB_URL#https://github.com/}"
  RUNNER_TOKEN=$(curl -sX POST \
    -H "Authorization: token ${GITHUB_PAT}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${OWNER_REPO}/actions/runners/registration-token" \
    | jq -r '.token')
  echo ":: Generated runner registration token via PAT"
fi

RUNNER_TOKEN="${RUNNER_TOKEN:?Either GITHUB_PAT or RUNNER_TOKEN is required}"
export RUNNER_TOKEN

# ── Remove stale config from previous run ───────────────────────────
if [ -f ".runner" ]; then
  echo ":: Removing stale runner config..."
  su runner -c "./config.sh remove --token '${RUNNER_TOKEN}'" 2>/dev/null || true
fi

# ── Configure (as runner) ───────────────────────────────────────────
su runner -c "./config.sh \
  --url '${GITHUB_URL}' \
  --token '${RUNNER_TOKEN}' \
  --name '${RUNNER_NAME}' \
  --labels '${RUNNER_LABELS}' \
  --work _work \
  --ephemeral \
  --unattended \
  --replace"

# ── Cleanup on exit ─────────────────────────────────────────────────
cleanup() {
  echo ":: Removing runner registration..."
  su runner -c "./config.sh remove --token '${RUNNER_TOKEN}'" 2>/dev/null || true
}
trap cleanup EXIT TERM INT

# ── Drop to runner user and start ───────────────────────────────────
exec su runner -c "./run.sh"
