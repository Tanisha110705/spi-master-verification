# Simulation Evidence

All images in this directory were extracted unmodified from the project
report. They are screenshots of the original Questa Sim runs. No text logs
or waveform databases were available.

## Waveforms (`waveforms/`)

| File | Content |
|---|---|
| `reset_waveform_questa.png` | Start of simulation: `i_Rst_L` pulse, inputs idled (`i_TX_DV = 0`, `i_TX_Byte = 00`), then `i_TX_Count` set to 3 by the generator |
| `mode0_waveform_questa.png` | SPI mode 0, full run of 5 transactions (also used as `assets/waveform.png`) |
| `mode1_waveform_questa.png` | SPI mode 1, full run |
| `mode2_waveform_questa.png` | SPI mode 2, full run |
| `mode3_waveform_questa.png` | SPI mode 3, full run |

## Transcripts (`logs/`)

Each mode has three consecutive screenshots of the Questa transcript:

| File | Content |
|---|---|
| `mode<N>_transcript_start.png` | Questa banner, the `vsim -coverage …` command with `spi_cov_mode<N>.ucdb`, test 1 |
| `mode<N>_transcript_middle.png` | Tests 2–3 and start of test 4 |
| `mode<N>_transcript_end.png` | End of test 4, test 5, `ALL TESTS COMPLETED SUCCESSFULLY`, `$finish` at 15805 ps |

The per-mode PASS counts and the decoded stimulus are summarised in
[`docs/results.md`](../docs/results.md).
