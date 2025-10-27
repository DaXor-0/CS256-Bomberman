`timescale 1ns/1ps

/**
* Module: vga_out
* Description: Main output module for VGA signals. Generates VGA timing signals,
* tracks current pixel coordinates, and outputs RGB color values based on input color and active video area.
*
* Parameters:
* - H_TOTAL: Total number of horizontal pixels (including sync, back porch, active, front porch)
* - V_TOTAL: Total number of vertical lines (including sync, back porch, active, front porch)
* - H_SYNC_END: End of horizontal sync pulse (in pixel clocks)
* - V_SYNC_END: End of vertical sync pulse (in lines)
* - H_ACTIVE_START: Start of active horizontal video (first visible pixel column)
* - H_ACTIVE_END: End of active horizontal video (last visible pixel column)
* - V_ACTIVE_START: Start of active vertical video (first visible row)
* - V_ACTIVE_END: End of active vertical video (last visible row)
* - BG_R, BG_G, BG_B: Background color when not in active area (default black)
*
* Inputs:
* - i_clk: 83.46 MHz clock input
* - i_rst: Reset signal
* - i_r, i_g, i_b: 4-bit per channel RGB input color
*
* Outputs:
* - o_hsync: o_Horizontal sync output
* - o_vsync: Vertical sync output
* - o_curr_x: Current pixel x-coordinate (0 to WIDTH-1)
* - o_curr_y: Current pixel y-coordinate (0 to HEIGHT-1)
* - o_pix_r, o_pix_g, o_pix_b: 4-bit per channel VGA color output
* */
module vga_out #(
    parameter int H_TOTAL         = 1680,
    parameter int V_TOTAL         = 828,
    parameter int H_SYNC_END      = 135,
    parameter int V_SYNC_END      = 2,
    parameter int H_ACTIVE_START  = 336,   // first visible pixel column
    parameter int H_ACTIVE_END    = 1615,  // last  visible pixel column
    parameter int V_ACTIVE_START  = 27,    // first visible row
    parameter int V_ACTIVE_END    = 826,   // last  visible row
    // Background color when not in active area
    parameter logic [3:0] BG_R = 4'h0,
    parameter logic [3:0] BG_G = 4'h0,
    parameter logic [3:0] BG_B = 4'h0
)(
    input  logic        i_clk, i_rst,
    input  logic [3:0]  i_r, i_g, i_b,

    output logic [3:0]  o_pix_r, o_pix_g, o_pix_b, // VGA color output
    output logic        o_hsync, o_vsync,      // horizontal and vertical sync
    output logic [10:0] o_curr_x,              // 0 .. (WIDTH-1)
    output logic [9:0]  o_curr_y               // 0 .. (HEIGHT-1)
);

  logic [10:0] hcount;
  logic [9:0]  vcount;
  logic active_screen;

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      hcount <= '0;
      vcount <= '0;
    end else begin
      if (hcount == H_TOTAL-1) begin
        hcount <= '0;
        if (vcount == V_TOTAL-1) vcount <= '0;
        else                     vcount <= vcount + 1;
      end else begin
        hcount <= hcount + 1;
      end
    end
  end

  assign o_hsync = (hcount > H_SYNC_END);
  assign o_vsync = (vcount > V_SYNC_END);

  assign active_screen = (hcount >= H_ACTIVE_START && hcount <= H_ACTIVE_END) &&
                         (vcount >= V_ACTIVE_START && vcount <= V_ACTIVE_END);

  always_comb begin
    o_curr_x <= hcount - H_ACTIVE_START;
    o_curr_y <= vcount - V_ACTIVE_START;
  end

  assign { o_pix_r, o_pix_g, o_pix_b } = active_screen ? { i_r, i_g, i_b } : { BG_R, BG_G, BG_B };

endmodule
