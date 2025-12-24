// Stub for Xilinx clock wizard used in simulation/lint only.
// Synthesis should fail if the real IP is not added to the project.
`timescale 1ns / 1ps

`ifndef SYNTHESIS
module clk_wiz_0 (
    input  wire clk_in1,
    output wire clk_out1
);
  // Simple fractional divider for simulation (~83.456 MHz from 100 MHz).
  localparam int unsigned PHASE_WIDTH = 32;
  localparam logic [PHASE_WIDTH-1:0] PHASE_STEP = 32'hD5A5B963;
  logic [PHASE_WIDTH-1:0] phase = '0;

  always_ff @(posedge clk_in1) begin
    phase <= phase + PHASE_STEP;
  end

  assign clk_out1 = phase[PHASE_WIDTH-1];
endmodule
`endif
