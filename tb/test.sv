//-----------------------------------------------------------------------------
// File        : test.sv
// Description : Self-checking test for SPI_Master_With_Single_CS.
//               Custom (non-UVM) SystemVerilog environment built from tasks:
//
//                 Generator : value_generation()  - random byte count + payload
//                 Driver    : reset()             - reset and idle the inputs
//                             send_byte()         - TX handshake (i_TX_DV/i_TX_Byte)
//                             send_miso()         - slave model driving MISO
//                 Monitor / : check_mosi()        - samples o_SPI_MOSI on SPI_Clk
//                 Checker                           edges and compares to tx_byte
//                             check_rx()          - compares o_RX_Byte on o_RX_DV
//                                                   against rx_byte
//                 Test      : test()              - fork of the 4 threads above
//                             initial block       - repeated reset/generate/test
//
// Source      : Transcribed from the project report ("Verification of SPI
//               Controller with Clock Polarity/Phase Modes"). Logic is
//               unchanged; indentation, section comments and this header were
//               added, and a non-ASCII glyph was removed from the
//               "Reset done" message.
//-----------------------------------------------------------------------------
module spi_test #(
  parameter int SPI_MODE          = 3,
  parameter int CLKS_PER_HALF_BIT = 5,
  parameter int MAIN_CLK_DELAY    = 5,
  parameter int MAX_BYTES_PER_CS  = 2,
  parameter int CS_INACTIVE_CLKS  = 10
)(
  spi_io.TB spi_io
);

  // Local variables
  logic [7:0] tx_byte[$];   // expected MOSI bytes (driven into the DUT)
  logic [7:0] rx_byte[$];   // MISO bytes (driven by the slave model)
  int tx_count, rx_count;
  int test_count = 1;

  // --------------------------- RESET ---------------------------
  // Driver: idle every DUT input, pulse active-low reset for 2 clocks,
  // then wait 10 clocks for the DUT to settle.
  task automatic reset();
    spi_io.cb.i_TX_Byte  <= 8'h00;
    spi_io.cb.i_TX_DV    <= 0;
    spi_io.cb.i_TX_Count <= 0;
    spi_io.cb.i_SPI_MISO <= 0;
    spi_io.i_Rst_L <= 0;
    repeat (2) @(spi_io.cb);
    spi_io.i_Rst_L <= 1'b1;
    repeat (10) @(spi_io.cb);
    $display("[%0t] Reset done", $time);
  endtask

  // ------------------------- SEND BYTE -------------------------
  // Driver (TX side): wait for o_TX_Ready, then present one byte with a
  // single-cycle i_TX_DV pulse.
  task automatic send_byte(input logic [7:0] tx_data);
    @(spi_io.cb);
    wait (spi_io.cb.o_TX_Ready);
    spi_io.cb.i_TX_Byte <= tx_data;
    spi_io.cb.i_TX_DV   <= 1'b1;
    @(spi_io.cb);
    spi_io.cb.i_TX_DV   <= 1'b0;
    $display("[%0t] Sent MOSI byte: 0x%0h", $time, tx_data);
  endtask

  // ------------------------- CHECK MOSI ------------------------
  // Monitor + checker (TX path): reconstruct one byte, MSB first, from
  // o_SPI_MOSI sampled on o_SPI_Clk edges. Modes 0/1 sample on posedge,
  // modes 2/3 on negedge. Compares the result with the expected byte.
  task automatic check_mosi(input logic [7:0] expected);
    bit sample_on_posedge;
    logic [7:0] observed;
    int bit_index;

    sample_on_posedge = (SPI_MODE == 0 || SPI_MODE == 1);
    observed  = '0;
    bit_index = 7;

    while (bit_index >= 0) begin
      if (sample_on_posedge)
        @(posedge spi_io.o_SPI_Clk);
      else
        @(negedge spi_io.o_SPI_Clk);
      observed[bit_index] = spi_io.o_SPI_MOSI;
      bit_index--;
    end

    if (observed === expected)
      $display("[%0t] PASS: MOSI correct (0x%0h)", $time, observed);
    else
      $error("[%0t] FAIL: MOSI mismatch exp=0x%0h got=0x%0h", $time, expected, observed);
  endtask

  // ------------------------- SEND MISO -------------------------
  // Driver (slave model): shift one byte MSB first onto i_SPI_MISO.
  //   Modes 0 and 2 (CPHA = 0): first bit is driven immediately after
  //     CS_n falls, the remaining bits after each negedge (mode 0) or
  //     posedge (mode 2) of o_SPI_Clk.
  //   Modes 1 and 3 (CPHA = 1): each bit is driven after a posedge
  //     (mode 1) or negedge (mode 3) of o_SPI_Clk.
  task automatic send_miso(input logic [7:0] miso_data);
    if ((SPI_MODE == 0) || (SPI_MODE == 2)) begin
      bit cpol = SPI_MODE[1];
      bit cpha = SPI_MODE[0];
      logic drive_edge;
      int bit_index = 7;
      if (cpol == 0 && cpha == 0) begin
        spi_io.cb.i_SPI_MISO <= miso_data[bit_index];
        @(negedge spi_io.o_SPI_Clk);
        bit_index--;
        while (bit_index >= 0) begin
          spi_io.cb.i_SPI_MISO <= miso_data[bit_index];
          @(negedge spi_io.o_SPI_Clk);
          bit_index--;
        end
      end
      else if (cpol == 0 && cpha == 1) begin
        @(posedge spi_io.o_SPI_Clk);
        while (bit_index >= 0) begin
          spi_io.cb.i_SPI_MISO <= miso_data[bit_index];
          @(posedge spi_io.o_SPI_Clk);
          bit_index--;
        end
      end
      else if (cpol == 1 && cpha == 0) begin
        spi_io.cb.i_SPI_MISO <= miso_data[bit_index];
        @(posedge spi_io.o_SPI_Clk);
        bit_index--;
        while (bit_index >= 0) begin
          spi_io.cb.i_SPI_MISO <= miso_data[bit_index];
          @(posedge spi_io.o_SPI_Clk);
          bit_index--;
        end
      end
      else begin
        @(negedge spi_io.o_SPI_Clk);
        while (bit_index >= 0) begin
          spi_io.cb.i_SPI_MISO <= miso_data[bit_index];
          @(negedge spi_io.o_SPI_Clk);
          bit_index--;
        end
      end
      spi_io.cb.i_SPI_MISO <= 0;
      $display("[%0t] Sent MISO byte (mode=%0d): 0x%0h", $time, SPI_MODE, miso_data);
    end
    else begin
      bit drive_on_posedge;
      drive_on_posedge = !((SPI_MODE == 0) || (SPI_MODE == 3));

      for (int i = 7; i >= 0; i--) begin
        if (drive_on_posedge)
          @(posedge spi_io.o_SPI_Clk);
        else
          @(negedge spi_io.o_SPI_Clk);
        spi_io.cb.i_SPI_MISO <= miso_data[i];
      end

      @(spi_io.cb);
      spi_io.cb.i_SPI_MISO <= 0;
      $display("[%0t] Sent MISO byte: 0x%0h", $time, miso_data);

    end
  endtask

  // -------------------------- CHECK RX -------------------------
  // Checker (RX path): on each o_RX_DV rising edge compare o_RX_Byte
  // with the byte the slave model sent.
  // NOTE: as written in the original project, the check also accepts
  // (expected - 1). See docs/results.md, "Known issues".
  task automatic check_rx(input logic [7:0] expected);
    @(posedge spi_io.o_RX_DV);

    if ((spi_io.o_RX_Byte === (expected)) || (spi_io.o_RX_Byte === (expected-1)) )
      $display("[%0t] PASS: RX data correct (0x%0h)", $time, expected);
    else
      $error("[%0t] FAIL: RX mismatch exp=0x%0h got=0x%0h", $time, expected, spi_io.o_RX_Byte);

  endtask

  // ---------------------- VALUE GENERATION ---------------------
  // Generator: clear both queues, pick a random byte count in
  // [1, MAX_BYTES_PER_CS], program i_TX_Count, and fill tx_byte/rx_byte
  // with random bytes in [0, 255].
  task automatic value_generation();
    tx_byte.delete();
    rx_byte.delete();

    tx_count = $urandom_range(1, MAX_BYTES_PER_CS);
    rx_count = tx_count;

    @(spi_io.cb);
    spi_io.cb.i_TX_Count <= tx_count;

    repeat (tx_count) tx_byte.push_back($urandom_range(0,255));
    repeat (rx_count) rx_byte.push_back($urandom_range(0,255));

    $display("[%0t] TX Count=%0d RX Count=%0d", $time, tx_count, rx_count);
    $display("[%0t] TX Bytes: %p", $time, tx_byte);
    $display("[%0t] RX Bytes: %p", $time, rx_byte);
  endtask

  // ------------------------ COMBINED TEST ----------------------
  // Run TX driver, MISO slave model, MOSI checker and RX checker in
  // parallel for one CS-low transaction.
  task automatic test();
    fork
      begin : TX_THREAD
        for (int j = 0; j < tx_count; j++) send_byte(tx_byte[j]);
      end

      begin : MISO_THREAD
        wait (spi_io.o_SPI_CS_n == 0);
        for (int i = 0; i < rx_count; i++) send_miso(rx_byte[i]);
      end

      begin : MOSI_MON_THREAD
        wait (spi_io.o_SPI_CS_n == 0);
        for (int j = 0; j < tx_count; j++) check_mosi(tx_byte[j]);
      end

      begin : RX_MON_THREAD
        wait (spi_io.o_SPI_CS_n == 0);
        for (int i = 0; i < rx_count; i++) check_rx(rx_byte[i]);
      end
    join
  endtask

  // ---------------------- MAIN TEST SEQUENCE -------------------
  // Each iteration: reset -> generate -> run one transaction -> wait for
  // the DUT to return to idle (TX ready, CS high) -> CS inactive gap.
  initial begin
    repeat (200) begin
      reset();
      value_generation();
      test();

      wait (spi_io.o_TX_Ready === 1);
      wait (spi_io.o_SPI_CS_n === 1);
      repeat (CS_INACTIVE_CLKS) @(spi_io.cb);

      $display("\n==== TEST %0d COMPLETE ====\n", test_count);
      test_count++;
    end

    $display("\n==== ALL TESTS COMPLETED SUCCESSFULLY ====\n");
    $finish;
  end

endmodule
