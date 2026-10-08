#!/usr/bin/env bash
#-----------------------------------------------------------------------------
# Questa Sim flow: one simulation per SPI mode, then merge coverage.
#
# Requires a licensed Siemens (Mentor) Questa/ModelSim installation with
# vlog/vsim/vcover on PATH. NOT executed as part of this repository's
# documentation work (no Questa licence was available).
#
# Provenance:
#   - The vsim command line is taken from the project's Questa transcripts
#     (see results/logs/mode*_transcript_start.png). Only -c (batch mode)
#     replaces the GUI "view wave; add wave" steps.
#   - The vlog/vcover lines are NOT shown in the report. They are the
#     standard commands needed to produce the coverage types that appear
#     in the report (statement, branch, expression, condition, FSM).
#
# Usage (from the repository root or from sim/):
#   sim/scripts/run_questa.sh            # modes 0 1 2 3 + merged report
#   sim/scripts/run_questa.sh 2          # mode 2 only
#-----------------------------------------------------------------------------
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${SIM_DIR}"

if [ "$#" -eq 0 ]; then set -- 0 1 2 3; fi
MODES=("$@")

for mode in "${MODES[@]}"; do
  work="work_mode${mode}"
  rm -rf "${work}"
  vlib "${work}"
  vlog -work "${work}" -sv +cover=sbecf \
       ../rtl/SPI_Master.v ../rtl/SPI_Master_With_Single_CS.v \
       ../tb/spi_io.sv ../tb/test.sv ../tb/spi_test_top.sv
  vsim -c -coverage -novopt -lib "${work}" -GSPI_MODE="${mode}" \
       -do "run -all; coverage report -details; coverage save spi_cov_mode${mode}.ucdb; quit -f" \
       spi_test_top | tee "transcript_mode${mode}.log"
done

if [ "${#MODES[@]}" -gt 1 ]; then
  vcover merge spi_cov_merged.ucdb spi_cov_mode*.ucdb
  vcover report -html -htmldir spi_cov_report spi_cov_merged.ucdb
  echo "Merged HTML coverage report: sim/spi_cov_report/index.html"
fi
