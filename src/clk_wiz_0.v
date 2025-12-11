// Stub for Xilinx clock wizard used in simulation/lint only.
// Synthesis should fail if the real IP is not added to the project.
`timescale 1ns / 1ps

`ifndef SYNTHESIS
module clk_wiz_0 (
    input  wire clk_in1,
    output wire clk_out1
);
  assign clk_out1 = 1'b0;
endmodule
`endif
