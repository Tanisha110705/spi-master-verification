//-----------------------------------------------------------------------------
// File        : spi_io.sv
// Description : Testbench <-> DUT interface for SPI_Master_With_Single_CS.
//               Bundles every DUT port and provides a clocking block (cb)
//               on posedge i_Clk so the testbench drives DUT inputs and
//               samples DUT outputs synchronously to the system clock.
//
//               The TB modport exposes:
//                 - cb             : synchronous drive/sample of DUT ports
//                 - i_Rst_L        : asynchronous reset, driven directly
//                 - o_RX_Byte, o_RX_DV, o_SPI_Clk, o_SPI_CS_n,
//                   o_SPI_MOSI, o_TX_Ready : raw (non-clocking-block)
//                   observation, used for SPI-clock-edge-aligned monitoring
//
// Source      : Transcribed from the project report ("Verification of SPI
//               Controller with Clock Polarity/Phase Modes"). Only
//               indentation and this header were added.
//-----------------------------------------------------------------------------
interface spi_io #(parameter MAX_BYTES_PER_CS = 2) (input bit i_Clk);
  logic i_Rst_L;
  logic [$clog2(MAX_BYTES_PER_CS+1)-1:0] i_TX_Count;
  logic [7:0] i_TX_Byte;
  logic i_TX_DV;
  logic i_SPI_MISO;
  logic o_TX_Ready;
  logic [$clog2(MAX_BYTES_PER_CS+1)-1:0] o_RX_Count;
  logic o_RX_DV;
  logic [7:0] o_RX_Byte;
  logic o_SPI_Clk;
  logic o_SPI_MOSI;
  logic o_SPI_CS_n;

  clocking cb @(posedge i_Clk);
    output i_TX_Count;
    output i_TX_Byte;
    output i_TX_DV;
    output i_SPI_MISO;
    input  o_TX_Ready;
    input  o_RX_Count;
    input  o_RX_DV;
    input  o_RX_Byte;
    input  o_SPI_Clk;
    input  o_SPI_MOSI;
    input  o_SPI_CS_n;
  endclocking: cb

  modport TB (
    clocking cb,
    output i_Rst_L,
    input  o_RX_Byte,
    input  o_RX_DV,
    input  o_SPI_Clk,
    input  o_SPI_CS_n,
    input  o_SPI_MOSI,
    input  o_TX_Ready
  );
endinterface
