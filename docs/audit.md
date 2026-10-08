# Evidence Audit: Report vs. Repository

This page records where every technical statement in this repository comes
from, and where the project report and the source disagree.

## Starting point

- The GitHub repository was **empty** when this work started: no commits,
  no branches, no files.
- The only project artefact was the report *"Verification of SPI Controller
  with Clock Polarity/Phase Modes"* (BEVD205L Scripting Languages and
  Verification, Fall 2025-26). It contains full code screenshots of `test.sv`,
  `spi_io.sv` and `spi_test_top.sv`, the first 69 lines of
  `SPI_With_Single_CS.v`, Questa waveforms and transcripts for each mode,
  and a Questa coverage summary.
- The report cites `github.com/nandland/spi-master/tree/master/Verilog/source`
  as its reference for the RTL.

## How the repository was rebuilt

| Item | Source | Fidelity |
|---|---|---|
| `rtl/SPI_Master_With_Single_CS.v`, `rtl/SPI_Master.v` | Upstream nandland/spi-master (MIT) | Unmodified. The visible part matches the report screenshot line for line, and the transcript shows `work.SPI_Master` loaded as a separate unit. |
| `tb/test.sv` | Report screenshots, listing lines 1–207 | Logic transcribed verbatim. Formatting, comments and header added. A non-ASCII glyph removed from the "Reset done" string. |
| `tb/spi_io.sv`, `tb/spi_test_top.sv` | Report screenshots | Verbatim apart from formatting and comments |
| `results/waveforms/*.png`, `results/logs/*.png`, `assets/waveform.png` | Images embedded in the report | Extracted unmodified |
| `assets/coverage.png` | Report coverage screenshot | Top 82 px cropped (browser title, URL and bookmarks bar, which showed an institutional host and home-directory path) |
| `sim/scripts/run_questa.sh` | `vsim` line from the transcripts. `vlog`/`vcover` lines inferred. | Not executed (no licence) |
| Diagrams in `assets/*.svg` | Drawn from the RTL and testbench source | Conceptual. `sim-waveform-mode*.svg` are rendered from a real Verilator VCD. |

## Facts confirmed

| Fact | RTL | Report | Notes |
|---|:-:|:-:|---|
| SPI master with single active-low chip select | ✔ | ✔ | |
| Modes 0–3 via `SPI_MODE`; CPOL = mode∈{2,3}, CPHA = mode∈{1,3} | ✔ | ✔ | |
| SCLK = i_Clk / (2·`CLKS_PER_HALF_BIT`), requires `CLKS_PER_HALF_BIT ≥ 2` | ✔ | ✔ | |
| Up to `MAX_BYTES_PER_CS` bytes per CS-low; `i_TX_Count` width `$clog2(MAX_BYTES_PER_CS+1)` | ✔ | ✔ | |
| CS held high for `CS_INACTIVE_CLKS` after a transfer | ✔ | ✔ | |
| MSB-first transmit and receive | ✔ | ✔ | |
| Bit counter, state machine | ✔ | ✔ | `r_TX_Bit_Count`, `r_RX_Bit_Count`, `r_SPI_Clk_Edges`; CS FSM `r_SM_CS` |
| "Shift registers" | ✘ | ✔ | The RTL indexes byte registers by a bit counter (`r_TX_Byte[r_TX_Bit_Count]`, `o_RX_Byte[r_RX_Bit_Count]`) instead of shifting. Functionally equivalent, but not literally shift registers. |
| `o_RX_DV` is a 1-cycle pulse when a byte is received | ✔ | ✘ | The report's port table says `o_RX_DV` indicates the master "is ready to accept the next transmit byte". That describes `o_TX_Ready`. The RTL comment and behaviour are "Data Valid pulse (1 clock cycle)". |
| `o_RX_Count` | ✔ | ✘ | The report says "number of bytes to be received". In the RTL it is a running index: cleared while CS is high, incremented on each `o_RX_DV`. |
| Generator / driver / monitor / checker tasks as named | — | ✔ | Confirmed by the transcribed `test.sv` |
| Questa Sim, one run per mode, 5 transactions each, all PASS | — | ✔ | Transcripts |
| Code coverage: total 90.03% (Hits %), 84.82% (Coverage %) | — | ✔ | Screenshot |

## Inconsistencies (not silently resolved)

| # | Report says | Evidence shows | How this repository handles it |
|---|---|---|---|
| 1 | "Functional coverage above 95%" | No covergroups, coverpoints or assertions in `test.sv`. The coverage summary lists code-coverage types only. | Functional coverage reported as **not implemented**. The 95% figure is not used. |
| 2 | "Code coverage above 90%" | Total Hits % = 90.03%; weighted Coverage % = 84.82%; DUT = 96.45% / 94.48% | All four numbers are quoted together with the metric they refer to. |
| 3 | "Constrained random stimulus" | `$urandom_range(lo, hi)` calls only. No `rand`, `constraint` or `randomize()`. | Described as "randomized stimulus with bounded ranges (`$urandom_range`)". |
| 4 | "Random seeds are logged so any failing test can be reproduced" | No seed is set or printed. All four runs show identical stimulus (default seed). | Documented as a limitation. |
| 5 | "Directed tests … known patterns (0x00, 0xFF, 0xA5)", "max/min TX count", "CS early release" | No directed tests in the testbench. Byte counts 1 and 5 do not occur in the logs. | Marked **Not tested** in the verification plan. |
| 6 | "Coverage-driven closure … drive generation until coverage goals reached" | Fixed `repeat` loop. No coverage feedback. | Not claimed. |
| 7 | `repeat (200)` in the code listing | Transcripts show 5 iterations | Listing kept as is. Discrepancy noted in [results.md](results.md#4-listing-vs-executed-run). |
| 8 | "Back-to-back transactions" and "idle bus" verified | `reset()` runs between every transaction. Idle levels are not checked automatically. | "Exercised" / "Not tested" in the plan. |
| 9 | "All tests passed without mismatches" | True for the recorded checks, but `check_rx()` accepts `expected − 1`, and modes 1/3 lose MISO bit 0 | Reported as passed, with known issues 1–2 in [results.md](results.md#known-issues). |
| 10 | "Generator … Passes these generated values to the driver tasks" (sequence/mailbox wording) | Values are shared through module-level queues read by forked threads | Described accurately. No mailbox or class is claimed. |
| 11 | Monitor described as continuously capturing; checker described as a "scoreboard" | `check_mosi()`/`check_rx()` each combine sampling and comparison. No scoreboard storage. | Described as "monitor + checker tasks". |
| 12 | Report's project tree lists `sim/Makefile` | Its contents are not in the report | Not reconstructed. `sim/scripts/run_questa.sh` replaces it and is labelled as such. |

## Information that is missing

- The original `sim/Makefile` and the `vlog` compile options.
- The detailed coverage report (per-line and per-condition misses), and what
  "Filtering Active" excluded.
- Text logs. Only transcript screenshots exist, and they are low resolution.
- Any functional-coverage model behind the "> 95%" claim.
- The exact `test.sv` that was simulated. The transcripts imply it differs
  from the listing at least in the iteration count.
