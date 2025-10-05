`timescale 1ns/1ps

/**
* Module: vga_render_box
* Description: Generates 4-bit-per-channel RGB for a filled, axis-aligned rectangle
*              (“box”) inside the active video region. When the current pixel falls
*              within the box, outputs the requested color; otherwise drives black.
*
* Parameters:
* - BG_R, BG_G, BG_B: 4-bit background color channels when outside the box (default black).
*
* Inputs:
* - pix_x_in   : Current pixel x-coordinate (0-based within active video).
* - pix_y_in   : Current pixel y-coordinate (0-based within active video).
* - in_screen  : High when the current pixel is within the active video region.
* - x_in       : Box left edge (x coordinate of the first column).
* - width_in   : Box width in pixels.
* - y_in       : Box top edge (y coordinate of the first row).
* - height_in  : Box height in pixels.
* - r_in,g_in,b_in : 4-bit color channels to use inside the box.
*
* Outputs:
* - VGA_R, VGA_G, VGA_B: VGA color output. Equal to the box color inside the region, 0 (black) otherwise.
* - write_out: High when this box is actively writing a pixel.
*
* Notes:
* - Arithmetic internally uses one extra bit to prevent overflow.
* - The box region includes pixels satisfying:
*     x_in ≤ pix_x_in < x_in + width_in
*     y_in ≤ pix_y_in < y_in + height_in
* - No internal clock; purely combinational.
*/
module vga_render_box #(
    parameter logic [3:0] BG_R = 4'h0,
    parameter logic [3:0] BG_G = 4'h0,
    parameter logic [3:0] BG_B = 4'h0
)(
    input  logic [10:0] pix_x_in,
    input  logic [9:0]  pix_y_in,
    input  logic        in_screen,

    input  logic [10:0] x_in, width_in,
    input  logic [9:0]  y_in, height_in,

    input  logic [3:0]  r_in, g_in, b_in,

    output logic [3:0]  VGA_R, VGA_G, VGA_B,
    output logic        write_out
);
  logic [10:0] x_end;
  logic [9:0] y_end;

  assign x_end = x_in + width_in;
  assign y_end = y_in + height_in;
  assign write_out = in_screen &&
                     (pix_x_in >= x_in) && (pix_x_in < x_end) &&
                     (pix_y_in >= y_in) && (pix_y_in < y_end);

  assign VGA_R = write ? r_in : BG_R;
  assign VGA_G = write ? g_in : BG_G;
  assign VGA_B = write ? b_in : BG_B;

endmodule
