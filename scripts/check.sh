#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

compiler=${ZIG:-zig}
if [[ -z ${ZIG:-} && -x .local/bin/zig ]]; then
    compiler="$PWD/.local/bin/zig"
fi
if [[ $("$compiler" version) != 0.16.0 ]]; then
    echo 'Zig 0.16.0 is required; run bash scripts/setup.sh.' >&2
    exit 1
fi

python3 scripts/test_public_content.py
python3 scripts/check_public_content.py
"$compiler" build -j2 "$@"
"$compiler" build test -j2 --summary all "$@"
