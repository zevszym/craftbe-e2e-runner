#!/bin/bash
set -euo pipefail

GITHUB_URL="${GITHUB_URL:?GITHUB_URL is required}"
RUNNER_NAME="${RUNNER_NAME:-craftbe-runner-$(hostname)}"
RUNNER_LABELS="${RUNNER_LABELS:-craftbe,playwright}"

# Auto-generate runner token from PAT (recommended for ephemeral runners)
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

# Remove stale config from previous run (e.g. after hard kill)
if [ -f ".runner" ]; then
  echo ":: Removing stale runner config..."
  ./config.sh remove --token "${RUNNER_TOKEN}" 2>/dev/null || true
fi

# Configure
./config.sh \
  --url "${GITHUB_URL}" \
  --token "${RUNNER_TOKEN}" \
  --name "${RUNNER_NAME}" \
  --labels "${RUNNER_LABELS}" \
  --work _work \
  --ephemeral \
  --unattended \
  --replace

# Cleanup on exit
cleanup() {
  echo "Removing runner registration..."
  ./config.sh remove --token "${RUNNER_TOKEN}" 2>/dev/null || true
}
trap cleanup EXIT TERM INT

# Start
exec ./run.sh
