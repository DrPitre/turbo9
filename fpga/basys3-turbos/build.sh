#!/usr/bin/env bash
set -euo pipefail
board=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$board/../.." && pwd)
image=${1:?Usage: build.sh path/to/turbos_dev.img}
python3 "$board/prepare.py" "$image"
"${APIO:-apio}" build -p "$repo/_build/basys3-turbos/rtl" -e basys3
python3 "$board/check_timing.py" "$repo/_build/basys3-turbos/rtl/_build/basys3/hardware.pnr"
