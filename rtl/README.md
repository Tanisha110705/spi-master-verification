# RTL: Design Under Test

| File | Module | Role |
|---|---|---|
| `SPI_Master_With_Single_CS.v` | `SPI_Master_With_Single_CS` | Top-level DUT. Adds a chip-select state machine, byte counting and `o_TX_Ready` gating around `SPI_Master`. |
| `SPI_Master.v` | `SPI_Master` | SPI clock/edge generation, MOSI bit selection and MISO capture for a single byte. Instantiated as `SPI_Master_Inst`. |

## Provenance

The DUT was not written as part of this project. The project report cites
[nandland/spi-master](https://github.com/nandland/spi-master/tree/master/Verilog/source)
as its reference. These two files are unmodified copies of
`Verilog/source/SPI_Master_With_Single_CS.v` and `Verilog/source/SPI_Master.v`
from that repository. They are released under the MIT License
(`LICENSE.nandland`, © 2019 russell-merrick).

The report's RTL screenshot (header comments, parameter defaults
`SPI_MODE = 0`, `CLKS_PER_HALF_BIT = 2`, `MAX_BYTES_PER_CS = 2`,
`CS_INACTIVE_CLKS = 1`, port list and the `IDLE / TRANSFER / CS_INACTIVE`
local parameters) matches these files line for line.

The testbench overrides the defaults from `tb/spi_test_top.sv`:
`CLKS_PER_HALF_BIT = 5`, `MAX_BYTES_PER_CS = 5`, `CS_INACTIVE_CLKS = 10`,
`SPI_MODE` = 0, 1, 2 or 3, one simulation per mode.
