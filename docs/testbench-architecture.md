# Testbench Architecture

![Verification environment](../assets/verification-environment.svg)

The environment is a **custom, task-based SystemVerilog testbench**. It has
no classes, no mailboxes and no UVM. The generator, driver, monitor and
checker roles are implemented as `automatic` tasks inside one module,
`spi_test`, and they communicate through shared queues (`tx_byte[$]`,
`rx_byte[$]`) and the `spi_io` interface.

## File overview

| File | Role | Important contents |
|---|---|---|
| `rtl/SPI_Master_With_Single_CS.v` | DUT top | CS state machine (`IDLE`, `TRANSFER`, `CS_INACTIVE`), `r_TX_Count`, `o_RX_Count`, `o_TX_Ready` gating. Instantiates `SPI_Master`. |
| `rtl/SPI_Master.v` | DUT core | `w_CPOL`/`w_CPHA` decode, SPI clock/edge generator, MOSI bit select, MISO capture, `o_RX_DV` pulse |
| `tb/spi_io.sv` | Interface | All DUT signals; `clocking cb @(posedge i_Clk)`; `modport TB` |
| `tb/test.sv` | Test program (module `spi_test`) | Tasks `reset`, `send_byte`, `check_mosi`, `send_miso`, `check_rx`, `value_generation`, `test`; main `initial` loop |
| `tb/spi_test_top.sv` | Top | `i_Clk` generator, parameters, instances of `spi_io`, `spi_test` and the DUT (`UUT`) |
| `sim/scripts/run_questa.sh` | Questa flow | Compile, one run per mode with coverage, UCDB merge, HTML report |
| `sim/scripts/run_verilator.sh` | Experimental | Open-source compile and run for first-transaction waveforms (see [results.md](results.md#open-source-re-run)) |
| `sim/scripts/vcd_to_svg.py` | Utility | Renders a VCD window as an SVG timing diagram with the DUT sampling edges marked |

> **Provenance:** the repository was empty when this documentation was
> written. The three `tb/` files were transcribed from the code screenshots
> in the project report. Only indentation, comments and file headers were
> added, and one non-ASCII glyph was removed from a `$display` string. The
> RTL is the unmodified upstream source the report cites. See
> [audit.md](audit.md).

## Hierarchy

```
spi_test_top
├── i_spi_io : spi_io #(.MAX_BYTES_PER_CS(5))           (tb/spi_io.sv)
├── test     : spi_test #(SPI_MODE, CLKS_PER_HALF_BIT=5, MAIN_CLK_DELAY=5,
│                         MAX_BYTES_PER_CS=5, CS_INACTIVE_CLKS=10)   (tb/test.sv)
└── UUT      : SPI_Master_With_Single_CS #(SPI_MODE, 5, 5, 10)     (rtl/)
    └── SPI_Master_Inst : SPI_Master #(SPI_MODE, 5)
```

## Interface: `spi_io`

```systemverilog
clocking cb @(posedge i_Clk);
  output i_TX_Count; output i_TX_Byte; output i_TX_DV; output i_SPI_MISO;
  input  o_TX_Ready; input o_RX_Count; input o_RX_DV; input o_RX_Byte;
  input  o_SPI_Clk;  input o_SPI_MOSI; input o_SPI_CS_n;
endclocking
modport TB (clocking cb, output i_Rst_L,
            input o_RX_Byte, o_RX_DV, o_SPI_Clk, o_SPI_CS_n, o_SPI_MOSI, o_TX_Ready);
```

- **Synchronous stimulus.** All DUT data inputs are driven through `cb`, so
  they change relative to `posedge i_Clk` and do not race the DUT's own
  `posedge i_Clk` logic.
- **Reset** (`i_Rst_L`) is driven directly. The DUT reset is asynchronous.
- **Raw outputs** (`o_SPI_Clk`, `o_SPI_MOSI`, `o_RX_DV`, `o_RX_Byte`, …) are
  also in the modport, so the monitors can wait on `o_SPI_Clk` edges and
  `posedge o_RX_DV` directly instead of on sampled `i_Clk` values.

## Components

### Generator: `value_generation()`

```systemverilog
tx_byte.delete();  rx_byte.delete();
tx_count = $urandom_range(1, MAX_BYTES_PER_CS);
rx_count = tx_count;
@(spi_io.cb);
spi_io.cb.i_TX_Count <= tx_count;
repeat (tx_count) tx_byte.push_back($urandom_range(0,255));
repeat (rx_count) rx_byte.push_back($urandom_range(0,255));
```

1. Clears the two byte queues.
2. Picks a byte count in [1, `MAX_BYTES_PER_CS`]. RX count equals TX count
   because SPI is full duplex.
3. Programs `i_TX_Count` on the DUT.
4. Fills the MOSI payload (`tx_byte`) and the MISO payload (`rx_byte`) with
   random bytes.
5. Prints the counts and both queues (`%p`).

A "transaction" here is the triple (`tx_count`, `tx_byte[$]`, `rx_byte[$]`).
There is no transaction class.

**Randomization mechanism:** `$urandom_range` with fixed bounds. There are no
`rand` variables, `constraint` blocks or `randomize()` calls. The only
"constraints" are the call arguments. The seed is never set or printed, so
every run uses the simulator's default seed, and all four mode runs produced
identical stimulus.

### Driver: `reset()`, `send_byte()`

```systemverilog
task automatic send_byte(input logic [7:0] tx_data);
  @(spi_io.cb);
  wait (spi_io.cb.o_TX_Ready);
  spi_io.cb.i_TX_Byte <= tx_data;
  spi_io.cb.i_TX_DV   <= 1'b1;
  @(spi_io.cb);
  spi_io.cb.i_TX_DV   <= 1'b0;
endtask
```

- `reset()` drives every input to 0, holds `i_Rst_L` low for 2 cycles, then
  waits 10 cycles.
- `send_byte()` implements the DUT's ready/valid handshake: wait for
  `o_TX_Ready`, present the byte with a one-cycle `i_TX_DV` pulse. The
  first pulse also starts the CS-low period, because the DUT moves IDLE →
  TRANSFER. Later pulses are accepted while `r_TX_Count > 0`.

### Slave model (MISO driver): `send_miso()`

This task models the external SPI slave. It shifts `rx_byte[i]` onto
`i_SPI_MISO` MSB first, synchronised to `o_SPI_Clk` edges chosen from
`SPI_MODE`. The per-mode edge table and an issue with the CPHA = 1 path are
in [spi-modes.md](spi-modes.md#3-how-the-testbench-models-each-mode-tbtestsv).

### Monitor and checker: `check_mosi()`, `check_rx()`

The report describes "Monitor" and "Checker / Scoreboard" separately. In the
code, each data path has one task that does both: it observes signals
passively (reads only, never drives) and compares the result immediately.
There is no separate scoreboard or stored transaction log.

```systemverilog
// check_mosi(): rebuild the byte from 8 MOSI samples
sample_on_posedge = (SPI_MODE == 0 || SPI_MODE == 1);
while (bit_index >= 0) begin
  if (sample_on_posedge) @(posedge spi_io.o_SPI_Clk);
  else                   @(negedge spi_io.o_SPI_Clk);
  observed[bit_index] = spi_io.o_SPI_MOSI;
  bit_index--;
end
if (observed === expected) $display("... PASS: MOSI correct ...");
else                       $error  ("... FAIL: MOSI mismatch exp=... got=...");
```

```systemverilog
// check_rx(): compare the DUT's parallel output when o_RX_DV rises
@(posedge spi_io.o_RX_DV);
if ((spi_io.o_RX_Byte === expected) || (spi_io.o_RX_Byte === expected-1))
  $display("... PASS: RX data correct ...");
else
  $error("... FAIL: RX mismatch exp=... got=...");
```

Data flow:

```
 value_generation()                       DUT
   tx_byte[j] ──► send_byte() ──► i_TX_Byte ──► o_SPI_MOSI ─┐
       │                                                    │ sampled on o_SPI_Clk edges
       └──────────────── expected ──► check_mosi() ◄────────┘──► PASS / $error

   rx_byte[i] ──► send_miso() ──► i_SPI_MISO ──► o_RX_Byte ─┐
       │                                         (o_RX_DV)  │
       └──────────────── expected ──► check_rx()   ◄────────┘──► PASS / $error
```

Mismatches use `$error`, so Questa counts them as errors. The coverage
report's "Error: 0" for all four tests reflects that count.

### Test sequencing: `test()` and the main `initial` block

`test()` forks four threads and joins all of them:

| Thread | Waits for | Loop |
|---|---|---|
| `TX_THREAD` | none | `send_byte(tx_byte[j])` for `j < tx_count` |
| `MISO_THREAD` | `o_SPI_CS_n == 0` | `send_miso(rx_byte[i])` for `i < rx_count` |
| `MOSI_MON_THREAD` | `o_SPI_CS_n == 0` | `check_mosi(tx_byte[j])` for `j < tx_count` |
| `RX_MON_THREAD` | `o_SPI_CS_n == 0` | `check_rx(rx_byte[i])` for `i < rx_count` |

Running TX, RX, MOSI checking and RX checking concurrently mirrors SPI's
full-duplex behaviour: every SCLK period moves one bit in each direction.

```
initial
  repeat (200)            // listing value; recorded runs show 5 iterations
    reset(); value_generation(); test();
    wait (o_TX_Ready === 1); wait (o_SPI_CS_n === 1);
    repeat (CS_INACTIVE_CLKS) @(cb);
    "==== TEST n COMPLETE ===="
  "==== ALL TESTS COMPLETED SUCCESSFULLY ===="   // printed unconditionally
  $finish
```

![One transaction, sequence view](../assets/transaction-flow.svg)

## Failure debugging flow

When a FAIL line appears, the environment provides the following
information. Each step lists where to look.

```
Mismatch ($error line)
  │  time stamp + expected + observed are printed
  ▼
Identify transaction ─ nearest preceding "TX Count=… / TX Bytes: … / RX Bytes: …"
  │                    and "TEST n COMPLETE" lines; test_count in the waveform
  ▼
Check expected data ─ which tx_byte[j] / rx_byte[i] the failing check compared
  ▼
Check MOSI / MISO ─ o_SPI_MOSI vs tx byte bits, i_SPI_MISO vs rx byte bits,
  │                 bit by bit, MSB first
  ▼
Check CS ─ o_SPI_CS_n low for the whole transaction? (not auto-checked)
  ▼
Check CPOL / CPHA ─ SPI_MODE in spi_test_top; o_SPI_Clk idle level after reset
  ▼
Check edge alignment ─ which edge check_mosi() sampled vs where MOSI changed;
  │                    when send_miso() changed MISO vs when the DUT sampled
  ▼
Check DUT state ─ UUT.r_SM_CS, UUT.r_TX_Count, SPI_Master_Inst.r_SPI_Clk_Edges,
  │               r_TX_Bit_Count, r_RX_Bit_Count, r_Leading_Edge, r_Trailing_Edge
  ▼
Locate root cause ─ DUT bug, testbench timing (driver/monitor edge), or stimulus
```

The CPHA = 1 bit-0 issue ([results.md](results.md#known-issues)) is a worked
example of this flow. With the tolerance removed, `check_rx()` would report
`exp=0x77 got=0x76`. The waveform then shows `i_SPI_MISO` returning to 0
before the last trailing-edge sample, which is a testbench (slave-model)
timing issue, not a DUT defect.
