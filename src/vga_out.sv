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
* - clk84mhz: 83.46 MHz clock input
* - rst: Reset signal
* - r_in, g_in, b_in: 4-bit per channel RGB input color
*
* Outputs:
* - VGA_HS: Horizontal sync output
* - VGA_VS: Vertical sync output
* - curr_x: Current pixel x-coordinate (0 to WIDTH-1)
* - curr_y: Current pixel y-coordinate (0 to HEIGHT-1)
* - VGA_R, VGA_G, VGA_B: 4-bit per channel VGA color output
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
    input  logic        clk84mhz, rst,
    input  logic [3:0]  r_in, g_in, b_in,

    output logic [3:0]  VGA_R, VGA_G, VGA_B, // VGA color output
    output logic        VGA_HS, VGA_VS,      // horizontal and vertical sync
    output logic [10:0] curr_x,              // 0 .. (WIDTH-1)
    output logic [9:0]  curr_y               // 0 .. (HEIGHT-1)
);

  logic [10:0] hcount;
  logic [9:0]  vcount;
  logic active_screen;

  always_ff @(posedge clk84mhz) begin
    if (rst) begin
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

  assign VGA_HS = (hcount > H_SYNC_END);
  assign VGA_VS = (vcount > V_SYNC_END);

  assign active_screen = (hcount >= H_ACTIVE_START && hcount <= H_ACTIVE_END) &&
                         (vcount >= V_ACTIVE_START && vcount <= V_ACTIVE_END);

  // Map to 0..WIDTH-1 / 0..HEIGHT-1 during active; hold last valid otherwise
  always_ff @(posedge clk84mhz) begin
    if (rst) begin
      curr_x <= '0;
      curr_y <= '0;
    end else begin
      if (active_screen) begin
        curr_x <= hcount - H_ACTIVE_START;
        curr_y <= vcount - V_ACTIVE_START;
      end
    end
  end

  assign { VGA_R, VGA_G, VGA_B } = active_screen ? { r_in, g_in, b_in } : { BG_R, BG_G, BG_B };

endmodule
