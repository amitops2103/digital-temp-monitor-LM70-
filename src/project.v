//------Digital Temperature Monitor Template----
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
  assign uio_oe  = 8'b00111011;// From Tiny-Tapeout
  assign uio_out[7:6] = 2'b00;
  assign uio_out[2] = 1'b0;

// === INPUT CONTROL ===
  wire sel_ob_LSB;
  wire sel_CorF;
  wire sel_disp_mode;
  assign sel_disp_mode = ui_in[0]; // 0 -> normal temperature, 1 -> show C or F
  assign sel_ob_LSB  = ui_in[1];       //DIP switch-2: if ui_in[0]=0: 1-> LSB, 0-> MSB
  assign sel_CorF   = ui_in[2];      // 0 -> Celsius, 1 -> Fahrenheit

// === INTERNAL SIGNALS ===
reg [4:0] cnt;
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
		cnt <= `RST_COUNT;
	else if (cnt == `MAX_COUNT)
		cnt <= `RST_COUNT;
	else
		cnt <= cnt + 1'b1;
end

// === STATE MACHINE ===
always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
		spi_state <= `SPI_IDLE;
	else begin
		case (cnt)
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

// ===== SHIFT REGISTER =====
reg [7:0] shift_reg;

always @(posedge SCK or negedge rst_n) begin
	if(!rst_n)
		shift_reg <= 8'h00;
	else
		shift_reg <= {shift_reg[6:0], SIO};
end

// === LATCH and CONVERT to Temperature ===
reg [7:0] temp_msb;
reg [7:0] temp_C;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		temp_msb <= 8'h00;
		temp_C   <= 8'h00;
	end
	else if (cnt == `SPI_LATCH_COUNT) begin
		temp_msb <= shift_reg;
		temp_C   <= shift_reg <<< 1; // Multiply by 2: LSB becomes 2°C
	end
end

// === C to F Conversion ===
// temp(F) = 2*C + 32  (Accurate: 9*C/5 +32)
// Error % is 0.62% at 0C and 9.43% at 100C
wire [7:0] temp_F;
assign temp_F = (temp_C << 1) + 8'd32;

// === MUX: Select between Celsius or Fahrenheit ===
wire [7:0] temp_select;
assign temp_select = sel_CorF ? temp_F : temp_C;

// ===== BCD conversion =====
wire [3:0] bcd_msb;
wire [3:0] bcd_lsb;
wire       bcd_lsb_carry;
//Temp/10 approx. 1/16 + 1/32
assign bcd_msb = (temp_select + (temp_select >> 1)) >> 4;
//LSB = temp - 10*MSB = temp - (8*MSB + 2*MSB)
assign bcd_lsb = temp_select - ((bcd_msb << 3) + (bcd_msb << 1));
// Capturing overflow bit
assign bcd_lsb_carry = bcd_lsb > 4'd9;

// === MUX: Select between MSB (tens) and LSB (ones) ===
wire [3:0] bcd_data;

assign bcd_data = sel_ob_LSB ? bcd_lsb : bcd_msb; // MUX logic

// === C and F 7-segment codes ===
wire [7:0] char_C;
wire [7:0] char_F;
assign  char_C = 8'b00111001; // 'C' display
assign  char_F = 8'b01110001; // 'F' display

// === C/F MUX Output ===
wire [7:0] seg_corf;
assign seg_CorF = sel_CorF ? char_F : char_C;

// === 7-Segment Decoder ===
reg [7:0] seg_bcd;

always @(*) begin
	case (bcd_data)
		4'd0: seg_bcd = 8'b00111111; // Display "0"
		4'd1: seg_bcd = 8'b00000110; // Display "1"
		4'd2: seg_bcd = 8'b01011011; // Display "2"
		4'd3: seg_bcd = 8'b01001111; // Display "3"
		4'd4: seg_bcd = 8'b01100110; // Display "4"
		4'd5: seg_bcd = 8'b01101101; // Display "5"
		4'd6: seg_bcd = 8'b01111101; // Display "6"
		4'd7: seg_bcd = 8'b00000111; // Display "7"
		4'd8: seg_bcd = 8'b01111111; // Display "8"
		4'd9: seg_bcd = 8'b01101111; // Display "9"
		default: seg_bcd = 8'b00000000; // Blank
	endcase
end

// === FINAL output selection MUX (7-segmenty display) ===
// sel_disp_mode == 0 -> display digit
// sel_disp_mode == 1 -> display C/F letter
assign uo_out = sel_disp_mode ? seg_CorF : seg_bcd;


 endmodule
