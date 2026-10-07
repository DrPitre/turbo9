#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
image=${1:?Usage: run_turbos_basys3.sh path/to/turbos_dev.img}
python3 "$repo/fpga/basys3-turbos/prepare.py" "$image"
project="$repo/_build/basys3-turbos/rtl"
cd "$project"
for stalls in 0 1; do
  "${IVERILOG:-iverilog}" -g2012 -I . -s tb_turbos_board \
    -Ptb_turbos_board.TX_STALL="$stalls" \
    -o "../board-$stalls.vvp" "$repo/tb/tb_turbos_basys3.v" ./*.v
  "${VVP:-vvp}" "../board-$stalls.vvp" | tee "../board-$stalls.log"
done
