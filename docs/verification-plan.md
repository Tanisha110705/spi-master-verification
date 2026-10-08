# Verification Plan and Status

This matrix starts from the verification plan in the project report and
records what the testbench actually does for each item. "Actual result" is
backed by the Questa transcripts, waveforms and coverage screenshot in the
report (copied to `results/` and `assets/`).

**Status legend**

| Status | Meaning |
|---|---|
| **Passed (self-checked)** | An automatic check in `tb/test.sv` compares expected vs actual, and the transcripts show PASS with no FAIL. |
| **Exercised** | The stimulus occurred in the recorded runs, but no automatic check covers this property. Evidence is waveform inspection or the absence of a hang. |
| **Partial** | Checked, but with a weakness that is documented. |
| **Not tested** | The recorded runs contain no stimulus for it. |

## Test matrix

| # | Test | Stimulus (as implemented) | Expected behaviour | Actual result |
|---|---|---|---|---|
| 1 | Reset | `reset()` before every transaction: inputs idled, `i_Rst_L` low for 2 `i_Clk` cycles, then 10 settle cycles | DUT idle: CS_n high, SCLK at CPOL level, no transfer | **Exercised.** Reset applied 5× per mode. The idle state is not checked automatically. The reset sequence is visible in `results/waveforms/reset_waveform_questa.png`. |
| 2 | Single-byte transmission (MOSI) | `send_byte()` drives each byte with an `i_TX_DV` pulse; `check_mosi()` rebuilds it from 8 `o_SPI_MOSI` samples | Bits shifted out MSB first, byte equals `tx_byte[j]` | **Passed (self-checked)** per byte: 17 bytes per mode, 68 in total, no FAIL. A transaction with `tx_count = 1` did not occur in the recorded runs (counts were 3, 2, 4, 4, 4). |
| 3 | Single-byte reception (MISO → `o_RX_Byte`) | `send_miso()` drives `rx_byte[i]`; `check_rx()` compares `o_RX_Byte` on each `o_RX_DV` rising edge | Assembled byte equals the MISO byte, one `o_RX_DV` per byte | **Passed** in modes 0 and 2. **Partial** in modes 1 and 3: the check accepts `expected − 1`, and the CPHA = 1 slave model drops bit 0 (see [results.md](results.md#known-issues)). |
| 4 | Multi-byte transfer | `tx_count` bytes per CS-low, `tx_count` random in [1, `MAX_BYTES_PER_CS` = 5] | CS_n stays low for the whole sequence; all bytes correct and in order | **Passed (self-checked) for data**, with byte counts 2, 3 and 4. CS_n continuity is **Exercised** only: the monitor threads wait for CS_n low once at the start and do not check that it stays low. Visible in the mode waveforms. |
| 5 | Continuous transfer without idle gap | Next byte is presented as soon as `o_TX_Ready` returns high inside the same CS-low period | No misalignment or corruption between consecutive bytes | **Exercised** inside multi-byte transactions, and data checks pass. Gap length is not measured, and there is no dedicated test. |
| 6 | Back-to-back transactions (CS high → low again) | Each transaction is followed by `CS_INACTIVE_CLKS` idle cycles **and a full `reset()`** | New transaction starts cleanly after CS_INACTIVE | **Not tested** as an un-reset back-to-back case, because `reset()` runs between every pair of transactions. |
| 7 | Idle bus behaviour | Wait for `o_TX_Ready` and `o_SPI_CS_n` high, then `CS_INACTIVE_CLKS` cycles | Lines hold idle levels, no toggling | **Exercised.** Not checked automatically. Visible in waveforms. |
| 8 | Clock and data alignment | `check_mosi()` samples on SPI_Clk edges; DUT samples MISO on its mode-defined edge | Data driven and sampled on the correct edges for the mode | **Partial.** MOSI checks pass in all modes, but `check_mosi()` samples on the leading edge in every mode, which is the launch edge for CPHA = 1 (see [spi-modes.md](spi-modes.md#observations-from-the-audit)). |
| 9 | Receive data-valid timing | `check_rx()` waits for `posedge o_RX_DV` once per expected byte | `o_RX_DV` asserts exactly once per byte at the end of the byte | **Partial.** A missing pulse would stall the test, and there is no timeout. Extra pulses are not detected. Pulse alignment is visible in waveforms. |
| 10 | TX ready handshake | `send_byte()` waits for `cb.o_TX_Ready` before each byte | `o_TX_Ready` high in IDLE and between bytes, low during a byte | **Exercised.** All bytes were accepted, so the handshake progressed. `o_TX_Ready` timing is not checked directly. |
| 11 | SPI mode 0 | `SPI_MODE = 0` run | CPOL 0 / CPHA 0 behaviour | **Passed** |
| 12 | SPI mode 1 | `SPI_MODE = 1` run | CPOL 0 / CPHA 1 behaviour | **Passed (MOSI) / Partial (RX)** |
| 13 | SPI mode 2 | `SPI_MODE = 2` run | CPOL 1 / CPHA 0 behaviour | **Passed** |
| 14 | SPI mode 3 | `SPI_MODE = 3` run | CPOL 1 / CPHA 1 behaviour | **Passed (MOSI) / Partial (RX)** |
| 15 | Random payloads | `$urandom_range(0,255)` per byte, both directions | Correct transfer of arbitrary byte values | **Passed** for 17 TX + 17 RX bytes per mode. All four runs used the same default seed, so the four modes saw identical byte values. |
| 16 | Random transaction length | `$urandom_range(1, MAX_BYTES_PER_CS)` | Correct CS framing for 1..5 bytes | **Partial.** Lengths 2, 3 and 4 occurred. 1 and 5 (the min/max boundaries) did not occur in the recorded runs. |
| 17 | SPI clock frequency | Fixed by `CLKS_PER_HALF_BIT = 5` | SCLK period = 2 × 5 `i_Clk` periods | **Exercised.** Not measured by the testbench. |
| 18 | `o_RX_Count` | Driven by the DUT | Increments once per received byte while CS_n is low | **Not checked.** The signal is visible in waveforms only. |
| 19 | Directed patterns (0x00, 0xFF, 0xA5), CS early release, max/min TX count | Listed under "Verification strategy" in the report | — | **Not tested.** No directed tests exist in the provided testbench. |

## Summary

- **Self-checked and passing:** MOSI data in all four modes, and RX data in
  modes 0 and 2, over 5 randomized transactions per mode.
- **Self-checked but weakened:** RX data in modes 1 and 3.
- **Exercised but not self-checked:** reset, CS framing, idle bus, TX-ready
  handshake, SCLK frequency, `o_RX_DV` count.
- **Not tested:** single-byte and 5-byte transactions, un-reset
  back-to-back transactions, directed corner patterns.

[Future improvements](../README.md#future-improvements) lists checks that
would close these gaps.
