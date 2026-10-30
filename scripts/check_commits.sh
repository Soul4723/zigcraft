#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
if [[ $# != 1 ]]; then
    echo 'Usage: bash scripts/check_commits.sh <base..head>' >&2
    exit 1
fi
scanner=${GITLEAKS:-"$PWD/.local/bin/gitleaks"}
python3 scripts/check_public_content.py --commits "$1"
"$scanner" git --redact --ignore-gitleaks-allow --log-opts="$1"
git log --format=%B "$1" -- | "$scanner" stdin --redact --ignore-gitleaks-allow
