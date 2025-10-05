`timescale 1ns/1ps

/**
* Module: vga_timing
* Description: Generates VGA timing signals and pixel coordinates based on standard VGA timing parameters.
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
* Inputs:
* - clk84mhz: 83.46 MHz clock input
* - rst: Reset signal
* Outputs:
* - VGA_HS: Horizontal sync output
* - VGA_VS: Vertical sync output
* - pix_x_out: Current pixel x-coordinate (0 to WIDTH-1)
* - pix_y_out: Current pixel y-coordinate (0 to HEIGHT-1)
* - sof_out: Start-of-frame (high for one clock at top-left)
* - eol_out: End-of-line (high for one clock at last pixel of each line)
* - in_screen_out: High when within active video area
*
* Functionality:
* - Generates horizontal and vertical sync signals based on timing parameters.
* - Tracks current pixel position and indicates when within the active video area.
* - Provides start-of-frame and end-of-line pulses for synchronization.
* */
module vga_timing #(
    parameter int H_TOTAL         = 1680,
    parameter int V_TOTAL         = 828,
    parameter int H_SYNC_END      = 135,
    parameter int V_SYNC_END      = 2,
    parameter int H_ACTIVE_START  = 336,   // first visible pixel column
    parameter int H_ACTIVE_END    = 1615,  // last  visible pixel column
    parameter int V_ACTIVE_START  = 27,    // first visible row
    parameter int V_ACTIVE_END    = 826    // last  visible row
)(
    input  logic        clk84mhz, rst,

    output logic        VGA_HS, VGA_VS,     // horizontal and vertical sync
    output logic [10:0] pix_x_out,          // 0 .. (WIDTH-1)
    output logic [9:0]  pix_y_out,          // 0 .. (HEIGHT-1)
    output logic        sof_out, eol_out,   // start of frame and end of line
    output logic        in_screen_out       // in active screen 
);

  logic [10:0] hcount;
  logic [9:0]  vcount;

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

  assign in_screen_out  = (hcount >= H_ACTIVE_START && hcount <= H_ACTIVE_END) &&
                          (vcount >= V_ACTIVE_START && vcount <= V_ACTIVE_END);

  // Map to 0..WIDTH-1 / 0..HEIGHT-1 during active; hold last valid otherwise
  always_ff @(posedge clk84mhz) begin
    if (rst) begin
      pix_x_out <= '0;
      pix_y_out <= '0;
    end else begin
      if (in_screen_out) begin
        pix_x_out <= hcount - H_ACTIVE_START;
        pix_y_out <= vcount - V_ACTIVE_START;
      end
    end
  end

  assign sof_out = (hcount == 0) && (vcount == 0);
  assign eol_out = (hcount == H_TOTAL-1);

endmodule
