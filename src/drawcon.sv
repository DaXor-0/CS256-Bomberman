`timescale 1ns/1ps

/**
* Module: drawcon
* Description: Draws a border and a block on the screen.
*
* Parameters:
* - SCREEN_W: Width of the screen in pixels.
* - SCREEN_H: Height of the screen in pixels.
* - BRD_SIZE: Thickness of the border in pixels.
* - BLK_W: Width of the block in pixels.
* - BLK_H: Height of the block in pixels.
* - BRD_R, BRD_G, BRD_B: Color of the border (4-bit each).
* - BLK_R, BLK_G, BLK_B: Color of the block (4-bit each).
* - BG_R, BG_G, BG_B: Background color (4-bit each).
*
* Inputs:
* - blkpos_x: X position of the block (top-left corner).
* - blkpos_y: Y position of the block (top-left corner).
* - draw_x: Current X position being drawn.
* - draw_y: Current Y position being drawn.
*
* Outputs:
* - r, g, b: Color values for the current pixel (4-bit each).
*/
module drawcon #(
    parameter int SCREEN_W       = 1280,
    parameter int SCREEN_H       = 800,
    parameter int BRD_SIZE       = 10,
    parameter int BLK_W          = 32,
    parameter int BLK_H          = 32,
    parameter logic[3:0] BLK_R   = 4'hF,             // Red block
    parameter logic[3:0] BLK_G   = 4'h0,
    parameter logic[3:0] BLK_B   = 4'h0,
    parameter logic[3:0] BRD_R =4'hF, BRD_G=4'hF, BRD_B = 4'hF, // White border
    parameter logic[3:0] BG_R = 4'h0, BG_G = 4'h0,  BG_B  = 4'h0  // Black background
)(
    input  logic [10:0] blkpos_x,
    input  logic [9:0]  blkpos_y,
    input  logic [10:0] draw_x,
    input  logic [9:0]  draw_y,
    output logic [3:0]  r, g, b,
    output logic obstacle
);

  logic is_border, is_blk;
  always_comb begin
      is_border = (draw_x < BRD_SIZE) || (draw_x >= SCREEN_W - BRD_SIZE) ||
                  (draw_y < BRD_SIZE) || (draw_y >= SCREEN_H - BRD_SIZE);
      is_blk = (draw_x >= blkpos_x) && (draw_x < blkpos_x + BLK_W) &&
               (draw_y >= blkpos_y) && (draw_y < blkpos_y + BLK_H);
      obstacle = (blkpos_x + BLK_W >= SCREEN_W - BRD_SIZE) || (blkpos_x <= BRD_SIZE) ||
                 (blkpos_y + BLK_H >= SCREEN_H - BRD_SIZE) || (blkpos_y <= BRD_SIZE);
  end

  always_comb begin
    { r, g, b } = { BG_R, BG_G, BG_B }; // Default to background color
    if (is_border) begin
      { r, g, b } = { BRD_R, BRD_G, BRD_B };
    end else if (is_blk) begin
      { r, g, b } = { BLK_R, BLK_G, BLK_B };
    end
  end

endmodule
