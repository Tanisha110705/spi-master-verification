# Coverage Evidence

| Evidence | Location |
|---|---|
| Questa Coverage Report summary (4 merged runs, one per SPI mode). Cropped to remove browser chrome with institutional host/path. | [`../assets/coverage.png`](../assets/coverage.png) |
| Transcribed numbers, explanation of Hits % vs Coverage %, limitations | [`../docs/coverage.md`](../docs/coverage.md) |

Summary: total code coverage is **90.03% (Hits %) / 84.82% (Coverage %)**,
and the DUT (`UUT`) scope is **96.45% / 94.48%**. Only code coverage
(statement, branch, expression, condition, FSM) was collected. No functional
coverage model exists in the testbench.

The original UCDB files (`spi_cov_mode0..3.ucdb`) and the full HTML report
were not available. `sim/scripts/run_questa.sh` regenerates them on a
machine with Questa.
