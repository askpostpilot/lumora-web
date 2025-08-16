#!/usr/bin/env bash
set -euo pipefail

# Always run from the repo root (folder containing this script)
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[INFO] Starting universal deploy…"

# Prefer a known-good script, in this order
CANDIDATES=(
"deploy-n8n-ip-mode.sh"
"deploy-n8n-vps-exact.sh"
"deploy-complete.sh"
)

TARGET=""

for f in "${CANDIDATES[@]}"; do
if [[ -f "$f" ]]; then
TARGET="$f"
break
fi
done

if [[ -z "${TARGET}" ]]; then
echo "[ERROR] No known deploy script found."
echo "Looked for:"
printf ' - %s\n' "${CANDIDATES[@]}"
echo "[INFO] Available deploy-like scripts:"
ls -1 deploy*.sh 2>/dev/null || true
exit 1
fi

chmod +x "$TARGET"
echo "[INFO] Running: $TARGET"
"./$TARGET"

echo "[INFO] Universal deploy complete."
