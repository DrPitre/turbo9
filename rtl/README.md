
# Top Level Files

|               |                                       |
|---------------|---------------------------------------|
| fpga_top.v    |  FPGA top                             |
|               |                                       |
| soc_top.v     |  SoC top 8-bit memory bus             |
| soc_top_r.v   |  SoC top 16-bit memory bus            |
| soc_top_gtr.v |  SoC top 16-bit Harvard memory bus    |
|               |                                       |
| turbo9.v      |  Turbo9 top 8-bit memory bus          |
| turbo9_r.v    |  Turbo9 top 16-bit memory bus         |
| turbo9_gtr.v  |  Turbo9 top 16-bit Harvard memory bus |
|               |                                       |

## BASYS3 TurbOS target

The [Turbo9S BASYS3 target](../fpga/basys3-turbos/README.md) boots TurbOS from
initialized RAM at 50 MHz, with timer and UART interrupts. It builds an isolated
Apio project and checks routed timing before reporting success.
