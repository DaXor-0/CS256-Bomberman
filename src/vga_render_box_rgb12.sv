`timescale 1ns/1ps

/**
* Module: vga_render_box_rgb12
* Description: Wrapper around `vga_render_box` that accepts 12-bit packed RGB input
*              and optionally specifies a background color.
*
* Parameters:
* - BG: 12-bit background color in RGB444 format (default: black, 12'h000)
*
* Inputs:
* - pix_x_in: Current pixel x-coordinate (0–H_ACTIVE_END)
* - pix_y_in: Current pixel y-coordinate (0–V_ACTIVE_END)
* - in_screen: High when the pixel is within the visible video area
* - x_in: X position of the top-left corner of the rendered box
* - width_in: Box width in pixels
* - y_in: Y position of the top-left corner of the rendered box
* - height_in: Box height in pixels
* - rgb_in: 12-bit RGB color (4 bits per channel: [11:8]=R, [7:4]=G, [3:0]=B)
*
* Outputs:
* - VGA_R: 4-bit red channel for VGA output
* - VGA_G: 4-bit green channel for VGA output
* - VGA_B: 4-bit blue channel for VGA output
* - write_out: High when this box is actively writing a pixel.
*
* Functionality:
* - Decomposes the 12-bit `rgb_in` into individual 4-bit R/G/B channels.
* - Delegates rendering to `vga_render_box`, which fills the defined rectangle area
*   when the current pixel lies within the box boundaries.
* - Outputs the specified color when inside the box, or the parameterized background
*   color (`BG`) otherwise.
*
* Typical Usage:
* - Used to draw static colored rectangles on screen (e.g., flags, UI panels, sprites).
* - Instantiate multiple modules with different coordinates and colors to overlay shapes.
*/
module vga_render_box_rgb12 #(
    parameter logic [11:0] BG = 12'h000,
  )(
    input  logic [10:0] pix_x_in,
    input  logic [9:0]  pix_y_in,
    input  logic        in_screen,

    input  logic [10:0] x_in, width_in,
    input  logic [9:0]  y_in, height_in,
    input  logic [11:0] rgb_in,

    output logic [3:0]  VGA_R, VGA_G, VGA_B,
    output logic        write_out
);

  vga_render_box #(
    .BG_R (BG[11:8]), .BG_G(BG[7:4]), .BG_B(BG[3:0])
    ) render_box_i (
    .pix_x_in   (pix_x_in),     .pix_y_in  (pix_y_in),
    .in_screen  (in_screen),
    .x_in       (x_in),         .width_in  (width_in),
    .y_in       (y_in),         .height_in (height_in),
    .r_in       (rgb_in[11:8]), .g_in      (rgb_in[7:4]), .b_in (rgb_in[3:0]),
    .VGA_R      (VGA_R),        .VGA_G     (VGA_G),       .VGA_B (VGA_B),
    .write_out  (write_out)
    );

endmodule
