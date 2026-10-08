//-----------------------------------------------------------------------------
// File        : spi_test_top.sv
// Description : Top-level simulation module.
//               - Generates the system clock i_Clk (half period MAIN_CLK_DELAY)
//               - Instantiates the spi_io interface
//               - Instantiates the test program (spi_test)
//               - Instantiates the DUT (SPI_Master_With_Single_CS, "UUT")
//               The same parameter set is passed to the interface, test and
//               DUT so all three agree on SPI_MODE and MAX_BYTES_PER_CS.
//
//               SPI_MODE is changed here (0, 1, 2, 3) to run each mode.
//               The report shows one simulation run per mode.
//
// Source      : Transcribed from the project report. Only indentation and
//               comments were added.
//-----------------------------------------------------------------------------
module spi_test_top();
  bit i_Clk = 0;
  parameter SPI_MODE          = 0;
  parameter CLKS_PER_HALF_BIT = 5;
  parameter MAIN_CLK_DELAY    = 5;
  parameter MAX_BYTES_PER_CS  = 5;
  parameter CS_INACTIVE_CLKS  = 10;

  always #(MAIN_CLK_DELAY) i_Clk = ~i_Clk;

  spi_io #(.MAX_BYTES_PER_CS(MAX_BYTES_PER_CS)) i_spi_io(i_Clk);

  spi_test #(
    .SPI_MODE(SPI_MODE),
    .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT),
    .MAIN_CLK_DELAY(MAIN_CLK_DELAY),
    .MAX_BYTES_PER_CS(MAX_BYTES_PER_CS),
    .CS_INACTIVE_CLKS(CS_INACTIVE_CLKS)
  ) test(i_spi_io);

  SPI_Master_With_Single_CS
    #(.SPI_MODE(SPI_MODE),
      .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT),
      .MAX_BYTES_PER_CS(MAX_BYTES_PER_CS),
      .CS_INACTIVE_CLKS(CS_INACTIVE_CLKS)
    ) UUT
    (
     .i_Rst_L(i_spi_io.i_Rst_L),
     .i_Clk(i_spi_io.i_Clk),
     .i_TX_Count(i_spi_io.i_TX_Count),
     .i_TX_Byte(i_spi_io.i_TX_Byte),
     .i_TX_DV(i_spi_io.i_TX_DV),
     .o_TX_Ready(i_spi_io.o_TX_Ready),
     .o_RX_Count(i_spi_io.o_RX_Count),
     .o_RX_DV(i_spi_io.o_RX_DV),
     .o_RX_Byte(i_spi_io.o_RX_Byte),
     .o_SPI_Clk(i_spi_io.o_SPI_Clk),
     .i_SPI_MISO(i_spi_io.i_SPI_MISO),
     .o_SPI_MOSI(i_spi_io.o_SPI_MOSI),
     .o_SPI_CS_n(i_spi_io.o_SPI_CS_n)
    );
endmodule
