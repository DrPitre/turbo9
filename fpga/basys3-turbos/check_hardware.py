"""Check the TurbOS shell and 60 Hz timer over the board's UART."""
import argparse
import time
from pathlib import Path

import serial

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--port', required=True, help='close other terminal apps first')
parser.add_argument('--wait-boot', action='store_true',
                    help='wait for boot instead of sending Return')
parser.add_argument('--log', type=Path, default=Path('hardware-session.log'))
args = parser.parse_args()


def until_prompt(port, log, timeout):
    data = b''
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        chunk = port.read(4096)
        if chunk:
            data += chunk
            log.write(chunk)
            log.flush()
            print(chunk.decode(errors='replace'), end='', flush=True)
            if b'TOS:' in data:
                return data
    raise RuntimeError('Timed out waiting for TOS: prompt')


with args.log.open('wb') as log, serial.Serial(args.port, 115200, timeout=.1) as port:
    if not args.wait_boot:
        port.write(b'\r')
    until_prompt(port, log, 55)
    for command in ('mfree', 'mdir', 'procs', 'sleep 60', 'mfree'):
        start = time.monotonic()
        for byte in (command + '\r').encode():
            port.write(bytes([byte]))
            time.sleep(.004)
        reply = until_prompt(port, log, 10)
        elapsed = time.monotonic() - start
        if command == 'mfree' and b'Total pages free' not in reply:
            raise RuntimeError('mfree failed')
        if command == 'sleep 60':
            print(f'\n60-tick sleep elapsed: {elapsed:.3f} seconds', flush=True)
            if not .8 < elapsed < 2.5:
                raise RuntimeError('Timer duration unexpected')
    print('\nPASS: physical TurbOS shell and 60 Hz timer', flush=True)
