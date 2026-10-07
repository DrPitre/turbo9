"""Fail the build if any reported clock misses its requested frequency."""
import argparse
import json
from pathlib import Path
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('report', type=Path)
args = parser.parse_args()
report = json.loads(args.report.read_text())
clocks = report['fmax']
if 'clk' not in clocks or clocks['clk']['constraint'] != 50.0:
    raise SystemExit('Missing 50 MHz CPU timing constraint')
failed = False
for clock, values in clocks.items():
    achieved, target = values['achieved'], values['constraint']
    print(f'{clock}: {achieved:.2f} MHz routed limit, {target:.2f} MHz target')
    failed |= achieved < target
if failed:
    raise SystemExit('FAIL: timing target not met; do not program this bitstream')
print('PASS: all reported clocks meet timing')
