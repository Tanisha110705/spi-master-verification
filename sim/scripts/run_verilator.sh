#!/usr/bin/env bash
#-----------------------------------------------------------------------------
# EXPERIMENTAL open-source cross-check with Verilator (tested: 5.48; 5.020
# fails with "Unsupported: Modport clocking"). Needs --timing and C++20.
#
# This is NOT the project's sign-off flow (that is Questa, see
# run_questa.sh). It exists so the reconstructed sources can be compiled and
# the first transaction inspected without a commercial licence.
#
# Two deviations from the Questa flow, both applied to copies of the sources
# in the build directory (the files in tb/ are not modified):
#   1. Verilator does not accept "spi_io.TB" (a modport that contains a
#      clocking block), so test.sv's port is declared as the plain interface.
#   2. A $dumpfile/$dumpvars block is added to spi_test_top so a VCD is written.
#
# Known divergence (observed with Verilator 5.48): Verilator applies the
# clocking-block drives in send_byte() one cycle later than Questa does,
# so on a multi-byte transaction the TX handshake drops a byte and
# check_mosi() reports a mismatch. Single-byte transactions match the Questa
# transcript timestamps exactly ([145] send, [905] PASS). Use these results
# only for waveform inspection of the first transaction.
#
# Usage: sim/scripts/run_verilator.sh <mode 0..3>
# Output: sim/build_verilator_mode<N>/{sim.log,dump.vcd}
#-----------------------------------------------------------------------------
set -uo pipefail

MODE="${1:-0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT}/sim/build_verilator_mode${MODE}"
rm -rf "${OUT}" && mkdir -p "${OUT}"

sed 's/^  spi_io\.TB spi_io$/  spi_io spi_io/' "${ROOT}/tb/test.sv" > "${OUT}/test_vl.sv"
sed 's/^endmodule/  initial begin $dumpfile("dump.vcd"); $dumpvars(0, spi_test_top); end\nendmodule/' \
    "${ROOT}/tb/spi_test_top.sv" > "${OUT}/spi_test_top_vl.sv"

verilator --binary --timing --trace -j 0 -CFLAGS -std=c++20 \
  -Wno-fatal -Wno-lint -Wno-style \
  --top-module spi_test_top -GSPI_MODE="${MODE}" --Mdir "${OUT}/obj" \
  "${ROOT}/rtl/SPI_Master.v" "${ROOT}/rtl/SPI_Master_With_Single_CS.v" \
  "${ROOT}/tb/spi_io.sv" "${OUT}/test_vl.sv" "${OUT}/spi_test_top_vl.sv" \
  > "${OUT}/build.log" 2>&1 || { echo "Verilator build failed, see ${OUT}/build.log"; exit 1; }

(cd "${OUT}" && ./obj/Vspi_test_top > sim.log 2>&1)
echo "Simulation log: ${OUT}/sim.log"
echo "Waveform:       ${OUT}/dump.vcd"
