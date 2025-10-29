`timescale 1ns/1ps

module game_top_tb;
  localparam CLK_PERIOD = 10;

  logic clk100 = 0;
  logic resetn = 0;
  logic up = 0, down = 0, left = 0, right = 0;
  logic [3:0] pix_r, pix_g, pix_b;
  logic hsync, vsync;

  game_top dut (
      .CLK100MHZ(clk100),
      .CPU_RESETN(resetn),
      .up(up),
      .down(down),
      .left(left),
      .right(right),
      .o_pix_r(pix_r),
      .o_pix_g(pix_g),
      .o_pix_b(pix_b),
      .o_hsync(hsync),
      .o_vsync(vsync)
  );

  always #(CLK_PERIOD/2) clk100 = ~clk100;

  initial begin
    $dumpfile("game_top_tb.vcd");
    $dumpvars(0, game_top_tb);

    repeat (5) @(posedge clk100);
    resetn = 1;

    // Run idle for a frame
    repeat (200000) @(posedge clk100);

    // Drive a sequence of joystick commands spaced by frame strobes
    up = 1'b1; repeat (200000) @(posedge clk100); up = 1'b0;
    down = 1'b1; repeat (200000) @(posedge clk100); down = 1'b0;
    left = 1'b1; repeat (200000) @(posedge clk100); left = 1'b0;
    right = 1'b1; repeat (200000) @(posedge clk100); right = 1'b0;

    repeat (200000) @(posedge clk100);
    $finish;
  end

endmodule

// Simulation stub for the clock wizard (pass-through)
module clk_wiz_0 (
    input  logic clk_in1,
    output logic clk_out1
);
  assign clk_out1 = clk_in1;
endmodule
