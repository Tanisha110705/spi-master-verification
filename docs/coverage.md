# Coverage

![Questa coverage report summary](../assets/coverage.png)

*Questa Coverage Report from the project report, with the browser title and
address bars cropped to remove institutional host and path information.
It summarises four tests (one per SPI mode). All four passed, with
0 warnings, 0 errors and 0 fatals.*

## What was measured

The coverage types in the report are all **code coverage**:

| Coverage type | Bins | Hits | Misses | % Hit | Coverage |
|---|---:|---:|---:|---:|---:|
| Statements | 191 | 177 | 14 | 92.67% | 92.67% |
| Branches | 60 | 55 | 5 | 91.66% | 91.66% |
| FEC Expressions | 13 | 12 | 1 | 92.30% | 92.30% |
| FEC Conditions | 20 | 12 | 8 | 60.00% | 60.00% |
| FSMs | 7 | 6 | 1 | 85.71% | 87.50% |
| ↳ FSM States | 3 | 3 | 0 | 100.00% | 100.00% |
| ↳ FSM Transitions | 4 | 3 | 1 | 75.00% | 75.00% |
| **Total** (filtering active) | | | | **90.03%** | **84.82%** |

| Design scope | Hits % | Coverage % |
|---|---:|---:|
| `spi_test_top` (whole hierarchy) | 90.03% | 84.82% |
| `i_spi_io` (interface) | 100.00% | 100.00% |
| `test` (testbench module `spi_test`) | 82.97% | 66.45% |
| `UUT` (DUT, including `SPI_Master_Inst`) | **96.45%** | **94.48%** |

### What the two percentages mean

- **% Hit / Hits %**: covered bins divided by total bins, counted across
  every coverage type.
- **Coverage %**: the average of the per-type percentages, each type
  weighted by its weight (all weights are 1 here). Low types such as FEC
  Conditions at 60% pull it down more than they pull down Hits %.

Both columns are shown in the report. The report text says "code coverage
above 90%". That is consistent with the **total Hits % of 90.03%** and with
both DUT figures (96.45% / 94.48%). The **weighted total is 84.82%**, so
quote "> 90%" together with which metric it refers to.

"Filtering Active" means a coverage filter or exclusion was applied when the
report was generated. The report does not say what was filtered.

## Functional coverage

The report's conclusion states "functional coverage above 95%". **No evidence
in the project supports this number:**

- The testbench (`tb/test.sv`, transcribed from the report) has no
  `covergroup`, `coverpoint`, `cover property` or assertion.
- The Questa summary lists only code-coverage types. There is no
  Covergroups or Assertions row.

So this repository reports functional coverage as **not implemented**. The
95% figure is not repeated anywhere else in the documentation. If a separate
functional-coverage model existed, its source and report would need to be
added for the claim to be supported.

## Limitations of these numbers

- **Code coverage is not proof of correctness.** A line can be executed
  without its effect being checked. For example, the RX path of modes 1 and 3
  is fully executed, but its bit 0 is never validated
  ([results.md](results.md#known-issues)).
- **The testbench scope is part of the total.** `test` is only 66.45%
  (Coverage %). Part of that comes from unreachable branches in `send_miso()`
  (the CPHA = 1 sub-branches inside the `MODE 0 || MODE 2` path) and FAIL
  branches that never execute in a passing run. That pulls the total below
  the DUT figure.
- **The individual misses are not itemised.** The report shows only the
  summary page. Without the detailed report, we cannot say which DUT
  conditions or which FSM transition were missed. A plausible candidate for
  the missed FSM transition is the `default` recovery arc of `r_SM_CS`, which
  normal operation cannot reach, but this is not confirmed.
- **Same seed in every run.** All four modes used identical random values,
  so merging the four runs adds coverage only through mode-dependent logic,
  not through new data.

## Reproducing

Code coverage collection requires Questa. `sim/scripts/run_questa.sh`
compiles with `+cover=sbecf`, runs each mode with `vsim -coverage`, saves
`spi_cov_mode<N>.ucdb`, merges the four UCDBs and writes an HTML report.
The `vsim` line is the one shown in the project transcripts. The `vlog` and
`vcover` lines are standard Questa usage inferred from the coverage types
in the report and were not run as part of this documentation work.
