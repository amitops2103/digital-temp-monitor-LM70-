`timescale 1ns/1ns

module tb ()
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  reg [15:0]TEMP_SET;
  wire SCK;
  wire CS;
  wire SIO;

// Instatiation of the DUT 
digital_temp_monitor_top  dut(
      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

//Instiate Temperature Sensor LM07
LM07 tsense(.TEMP_SET(TEMP_SET),.CS(CS), .SCK(SCK), .SIO(SIO));

//DUT <-> LM07 Connections
assign CS = uio_out[0];
assign SCK = uio_out[1];
//uio_in[2] is reg so cannot be 'assigned'
always @(*) begin
       	uio_in[2] <= SIO;
end

//********INITIALS****************
//Initialize CS
// Dump the signals to a VCD file. You can view it with gtkwave.
initial begin
  $dumpfile("tb.vcd");
  $dumpvars(0, tb);
  rst_n = 1'b0;
  TEMP_SET = 16'h0033;
  clk = 1'b1;
  ena = 1'b1;
  #10;
    rst_n = 1'b1;
  #700;
  $finish(2);   
end


//Generate test clock
initial forever #10 clk = ~clk;    

endmodule
// end tb



//------------------------------------------------------------------------------------------------------------------------------------------------//
///////TEMP SENSOR LM70 DUMMY MODEL/////////////////
//Define
// In this design we only read the 8-MSBs 
// which has a resolution of 2-deg C 
    
////////////////////////////////////////////////////////////////////////////
// Verilog model for the SPI-based temperature 
// sensor LM07 or it's equivalent family.
//
module LM07(TEMP_SET,CS, SCK, SIO);
  output SIO;
  input SCK, CS;
  input [15:0] TEMP_SET;
  //
  // lm07_reg represents the register that stores
  // temperature value after A2D conversion
  // FIXME: Model the A2D
  reg [15:0] shift_reg;
  wire clk_gated;
  
  //Reset at startup
  initial begin
    shift_reg = TEMP_SET; 
    //shift_reg = shift_reg>>1;
  end
  
  //SIO bit of the LM07 is hardwired output of
  // the MSB of the shift register
  assign SIO = shift_reg[15];

  //Gate the clock with CS
  assign clk_gated = ~CS & SCK;
  
  // When CS goes low, load temp_shift_reg with lm07_reg
  // If high, reset
  always @(CS)
   begin
     shift_reg = TEMP_SET;
     //shift_reg = shift_reg>>1;
   end
  
  //Shift register to shift the loaded temp reg
  //every negedge of the gated clock
  always @(negedge clk_gated)
    begin
      shift_reg = shift_reg<<1;
    end
  /*initial begin
    $monitor("data=%0b,dataseg=%0b,dataout=%0b",SIO,dataSeg,dbugout);
  end*/
endmodule
/////////////////////////////////////////
    
