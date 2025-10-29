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
    input  logic       up,
    input  logic       down,
    input  logic       left,
    input  logic       right,
    input  logic       obstacle_up,
    input  logic       obstacle_down,
    input  logic       obstacle_left,
    input  logic       obstacle_right,
    output logic [10:0] blkpos_x,
    output logic [9:0]  blkpos_y
);

  always_ff @(posedge clk) begin
    if (rst) begin
      blkpos_x <= INIT_X;
      blkpos_y <= INIT_Y;
    end else if (tick) begin
      if (up && !obstacle_up) blkpos_y <= blkpos_y - STEP_SIZE;
      else if (down && !obstacle_down) blkpos_y <= blkpos_y + STEP_SIZE;

      if (left && !obstacle_left) blkpos_x <= blkpos_x - STEP_SIZE;
      else if (right && !obstacle_right) blkpos_x <= blkpos_x + STEP_SIZE;
    end
  end

endmodule
