//------Digital Temperature Monitor Template-----
/*
 * Copyright (c) 2025 Silicon University, Odisha, India
 */
//`timescale 1ns / 1ps
//Put your DEFINES here
// === DEFINES ===
`define RST_COUNT        5'd0
`define CS_LOW_COUNT     5'd4
`define CS_HIGH_COUNT    5'd20
`define SPI_LATCH_COUNT  5'd22
`define MAX_COUNT        5'd28

`define SPI_IDLE   2'b00
`define SPI_READ   2'b01
`define SPI_LATCH  2'b10

// DO NOT CHANGE THIS MODULE
module digital_temp_monitor_top (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock e.g. provide a 10 kHz clock
    input  wire       rst_n     // reset_n - low to reset
);

  // === OUTPUT ASSIGNMENTS ===
  // All output pins must be assigned. If not used, assign to 0.
  // The enables may not be auto checked. 
  assign uio_oe  = 8'b00111011;
  assign uio_out[7:6] = 2'b00;
  assign uio_out[2] = 1'b0;

// === INPUT CONTROL ===
  assign sel_ob_LSB  = ui_in[1];       //DIP switch-2: if ui_in[0]=0: 1-> LSB, 0-> MSB

// === INTERNAL SIGNALS ===
reg [4:0] count;
reg [1:0] spi_state;
reg SCK;
wire CS;
wire SIO = uio_in[2];

// === IO OUTPUT ===
assign uio_out[0] = CS;  // CS signal
assign uio_out[1] = SCK; // SPI clock

// === COUNTER (0 to 28) ===
always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    count <= `RST_COUNT;
  else if (count == `MAX_COUNT)
    count <= `RST_COUNT;
  else
    count <= count + 1'b1;
end

// === STATE MACHINE ===
always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    spi_state <= `SPI_IDLE;
  else begin
    case (count)
      `CS_LOW_COUNT:     spi_state <= `SPI_READ;
      `CS_HIGH_COUNT:    spi_state <= `SPI_IDLE;
      `SPI_LATCH_COUNT:  spi_state <= `SPI_LATCH;
      default:           spi_state <= `SPI_IDLE;
    endcase
  end
end

// === CS Signal (active LOW during READ) ===
assign CS = ~(spi_state == `SPI_READ);

// === SPI CLOCK Generation (clk / 2 during READ) ===
always @(negedge clk or negedge rst_n) begin
  if (!rst_n)
    SCK <= 1'b0;
  else if (CS)
    SCK <= 1'b0; // Disable SCK when CS is high (IDLE)
  else
    SCK <= ~SCK; // Toggle SCK on negedge of clk
end

// === OUTPUT to 7-segment (not yet used) ===
assign uo_out = 8'b00000000;
 endmodule
