#!/usr/bin/env python3
"""Prepare an isolated Apio project from shared RTL and a 64 KiB TurbOS image."""
import argparse
import hashlib
import shutil
from pathlib import Path

board = Path(__file__).resolve().parent
repo = board.parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('image', type=Path, help='turbos_dev.img from the turbo9sim port')
args = parser.parse_args()
data = args.image.read_bytes()
if len(data) != 65536:
    parser.error('TurbOS image must contain exactly 65,536 bytes, including vectors')
project = repo / '_build/basys3-turbos/rtl'
project.mkdir(parents=True, exist_ok=True)
for pattern in ('*.v', '*.vh', '*.hex'):
    for source in (repo / 'rtl').glob(pattern):
        shutil.copy2(source, project / source.name)
for source in (board / 'rtl').glob('*.v'):
    shutil.copy2(source, project / source.name)
for name in ('apio.ini', 'fpga_top_basys3.xdc'):
    shutil.copy2(board / name, project / name)
for name, bank in (('even', data[::2]), ('odd', data[1::2])):
    (project / f'turbos_{name}.hex').write_text(''.join(f'{byte:02x}\n' for byte in bank))
(project.parent / 'image.sha256').write_text(hashlib.sha256(data).hexdigest() + '\n')
print(project)
