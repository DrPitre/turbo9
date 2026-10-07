# TurbOS on BASYS3 with Turbo9S

This target boots the TurbOS development shell directly from initialized FPGA
RAM. It uses `turbo9_s` (CPU type 1), a shared aligned 16-bit Wishbone bus,
64 KiB RAM, a 60 Hz interrupt timer, and a 115200-baud UART terminal.
The CPU runs at 50 MHz from the board's 100 MHz oscillator.

## Build

Requirements: Python 3, Apio 1.6.0 with the openXC7 and OSS CAD Suite packages,
and a complete 65,536-byte `turbos_dev.img` from the TurbOS `turbo9sim` port.
The image must include its reset and interrupt vectors. Software binaries are
not bundled here.

Build the image in a prepared TurbOS checkout (see its upstream-source instructions):

```sh
make -C "$TURBOSDIR/ports/turbo9sim" TURBOSDIR="$TURBOSDIR" turbos_dev.img
```

From this repository's root, with Apio on `PATH`:

```sh
bash fpga/basys3-turbos/build.sh "$TURBOSDIR/ports/turbo9sim/turbos_dev.img"
```

Alternatively set `APIO` to the absolute path of the Apio executable. The script
copies shared RTL and board-specific overrides into `_build/basys3-turbos/rtl`,
splits the image into even/odd byte banks, and builds the bitstream. It does not
modify the shared RTL or the TurbOS checkout. The bank files and bitstream are
build artifacts rather than source files.

The script explicitly checks the final routing report. An Apio success message
alone is insufficient: the tools can produce a bitstream that misses timing.
`check_timing.py` requires a 50 MHz CPU constraint and checks every reported clock.

## Program and connect

Disconnect any open serial terminal before programming:

```sh
apio upload -p _build/basys3-turbos/rtl -e basys3
```

This programs FPGA SRAM, not flash. Reload after a power cycle. Keep SW15, the
leftmost bottom slide switch, up to release reset. Center button is CPU reset.
The green DONE light indicates FPGA configuration completed.

Connect the board's UART port at **115200 8N1, no flow control**. On the validated
Mac, the working endpoint was `/dev/cu.usbserial-210183AF2E261`; device names vary.
In Serial for macOS, use **Immediate** send mode and turn **Echo Sent Characters**
off. TurbOS supplies character echo; line-buffered local input causes an apparent
second command echo after Return.

The `TOS:` shell includes `mfree`, `mdir`, `procs`, and `sleep`. This development
image has built-in commands but no FPGA storage controller or external filesystem.

## Hardware interface

| Address | Read | Write |
| --- | --- | --- |
| `$FF00` | zero | UART transmit byte |
| `$FF01` | UART receive byte | ignored |
| `$FF02` | IRQ status | Write-one-to-clear status |
| `$FF03` | IRQ enable register | IRQ enable register |

Bit 0 is the timer source and bit 1 is UART receive. Enabled pending sources
assert IRQ. FIRQ and NMI are inactive. Read the receive byte before acknowledging
its status bit. New timer events take priority over simultaneous acknowledgement.

The UART's registered transmit-full state pauses the shared Wishbone interface
and retains its pending response. The timer and UART continue running during a
bus pause. This simple backpressure mechanism trades CPU throughput during output
for a small, lossless transmit interface. The receive hardware has one holding
byte; it is not a bulk-transfer FIFO.

The memory bus uses high/even and low/odd byte lanes. The standard Turbo9S bridge
arbitrates instruction and data requests and splits unaligned words into aligned
transfers. Its output registers are enabled and the fetch queue size is six.
Board-specific copies of the top, clock divider, and UART keep the original
platform-independent targets unchanged.

## Verification

Run the real SoC and Wishbone bridge against the development image, both with
an always-ready transmitter and with repeated transmit stalls:

```sh
apio raw -- bash sim/run_turbos_basys3.sh "$TURBOSDIR/ports/turbo9sim/turbos_dev.img"
```

The simulation accelerates the timer and substitutes UART byte signals. It checks
shell boot, `mfree`, six receive acknowledgements, timer acknowledgements, and
aligned Wishbone addresses. Physical UART operation is checked separately.

With other terminal apps disconnected and PySerial installed:

```sh
python3 fpga/basys3-turbos/check_hardware.py \
  --port /dev/cu.usbserial-210183AF2E261 \
  --log _build/basys3-turbos/hardware-session.log
```

This sends Return to an already running shell, runs `mfree`, `mdir`, `procs`,
`sleep 60`, and `mfree` again, and then closes the port. `--wait-boot` waits for an
initial prompt instead. Reconnect your terminal afterward.

Validated October 6, 2026 on BASYS3 with TurbOS
`b5d22c00c283b03ca2cb539ed4eb3584bef613cc` and its pinned NitrOS-9 imports:

- `mfree`: 192 pages (48 KiB) free.
- `mdir` and `procs`: module and process listings returned.
- `sleep 60`: 1.070 seconds, followed by another successful command.
- The UART-stall simulation passed with six RX and 45 timer acknowledgements.
- Routed CPU timing limit: **62.08 MHz**, meeting the 50 MHz target.
- The packaged build reproduces the hardware-tested FASM and configuration
  frames byte for byte.
- Synthesis uses `-flatten -abc9`; routing uses seed 1 and `--freq 50`.

These are routed timing and functional hardware checks, not a long-duration
stress test. The full FPGA implementation is reproducible from the source and
external image; no generated bitstream is committed.
