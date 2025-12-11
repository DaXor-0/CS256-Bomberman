`timescale 1ns/1ps

module game_top_tb;
  localparam CLK_PERIOD = 10;

  logic clk100 = 0;
  logic resetn = 0;
  logic up = 0, down = 0, left = 0, right = 0;
  logic place_bomb = 0;
  logic uart_rx = 1'b1;
  logic [4:0] leds;
  logic [3:0] pix_r, pix_g, pix_b;
  logic hsync, vsync;
  logic game_over;
  logic CA, CB, CC, CD, CE, CF, CG;
  logic [7:0] AN;

  game_top dut (
      .CLK100MHZ(clk100),
      .CPU_RESETN(resetn),
      .up(up),
      .down(down),
      .left(left),
      .right(right),
      .place_bomb(place_bomb),
      .uart_rx(uart_rx),
      .LED(leds),
      .game_over(game_over),
      .o_pix_r(pix_r),
      .o_pix_g(pix_g),
      .o_pix_b(pix_b),
      .o_hsync(hsync),
      .o_vsync(vsync),
      .CA(CA), .CB(CB), .CC(CC), .CD(CD), .CE(CE), .CF(CF), .CG(CG),
      .AN(AN)
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
    place_bomb = 1'b1; repeat (10) @(posedge clk100); place_bomb = 1'b0;
    right = 1'b1; repeat (200000) @(posedge clk100); right = 1'b0;

    repeat (200000) @(posedge clk100);
    $finish;
  end

endmodule
