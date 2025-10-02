`timescale 1ns / 1ps

module vga_out #(
    parameter H_TOTAL = 1680,
    parameter V_TOTAL = 828,
    parameter H_SYNC_END = 135,
    parameter V_SYNC_END = 2,
    parameter H_ACTIVE_START = 336,
    parameter H_ACTIVE_END = 1615,
    parameter V_ACTIVE_START = 27,
    parameter V_ACTIVE_END = 826
    )(
    input clk, rst,
    input [3:0] in_r, in_b, in_g,
    output [3:0] VGA_R, VGA_G, VGA_B,
    output VGA_HS, VGA_VS
    );

  logic [10:0] hcount; logic [9:0] vcount;
  logic in_screen;
 
  always_ff @(posedge clk) begin
    if (rst) begin 
      hcount <= '0; 
      vcount <= '0;
    end else begin
      if (hcount >= H_TOTAL - 1) begin
        hcount <= '0;
        if (vcount >= V_TOTAL - 1)  vcount <= '0;
        else                        vcount <= vcount + 1;
      end else begin
        hcount <= hcount + 1;
      end
    end
  end

  assign VGA_HS = (hcount > H_SYNC_END);
  assign VGA_VS= (vcount > V_SYNC_END);

  assign in_screen = 
      (hcount >= H_ACTIVE_START && hcount <= H_ACTIVE_END) &&
      (vcount >= V_ACTIVE_START && vcount <= V_ACTIVE_END);

  assign VGA_R = (in_screen) ? in_r : '0;
  assign VGA_G = (in_screen) ? in_g : '0;
  assign VGA_B = (in_screen) ? in_b : '0;

endmodule
