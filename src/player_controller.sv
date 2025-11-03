`timescale 1ns/1ps

/**
* Module: player_controller
* Description: Updates the player block position based on input commands and obstacle flags.
*/
module player_controller #(
    parameter int INIT_X = 800,
    parameter int INIT_Y = 400,
    parameter int STEP_SIZE = 4,
    parameter int NUM_ROW = 11,
    parameter int NUM_COL = 19,
    localparam int DEPTH = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       tick,
    input  logic[3:0]  move_dir,
    input  logic[1:0]  map_mem_in,
    output logic[10:0]           player_x,
    output logic[9:0]            player_y,
    output logic[ADDR_WIDTH-1:0] map_addr
);

  // obstacle detection
  logic obstacle_up, obstacle_down, obstacle_left, obstacle_right;
  check_obst #(
    .NUM_ROW(NUM_ROW),
    .NUM_COL(NUM_COL)
  ) check_obst_i (
    .clk(clk),
    .rst(rst),
    .player_x(player_x),
    .player_y(player_y),
    .obstacles({obstacle_up, obstacle_down, obstacle_left, obstacle_right}),
    .map_addr(map_addr)
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
