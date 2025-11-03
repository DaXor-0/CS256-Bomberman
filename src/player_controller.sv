`timescale 1ns/1ps

/**
* Module: player_controller
* Description: Updates the player block position based on input commands and obstacle flags.
*/
module player_controller #(
    parameter int INIT_X = 800,
    parameter int INIT_Y = 400,
    parameter int STEP_SIZE = 4
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       tick,
    input  logic[3:0]  move_dir,
    input  logic[3:0]  obstacles,
    input  logic       obstacle_up,
    input  logic       obstacle_down,
    input  logic       obstacle_left,
    input  logic       obstacle_right,
    output logic[10:0] blkpos_x,
    output logic[9:0]  blkpos_y
);


  always_ff @(posedge clk) begin
    if (rst) begin
      blkpos_x <= INIT_X;
      blkpos_y <= INIT_Y;
    end else if (tick) begin
      case (move_dir)
        4'b1000: if (!obstacle_up)    blkpos_y <= blkpos_y - STEP_SIZE; // Up
        4'b0100: if (!obstacle_down)  blkpos_y <= blkpos_y + STEP_SIZE; // Down
        4'b0010: if (!obstacle_left)  blkpos_x <= blkpos_x - STEP_SIZE; // Left
        4'b0001: if (!obstacle_right) blkpos_x <= blkpos_x + STEP_SIZE; // Right
        default: ; // No movement or conflicting inputs
      endcase
    end
  end

endmodule
