`timescale 1ns / 1ps


module check_obst #(
  parameter int NUM_ROW = 11,
  parameter int NUM_COL = 19,
  localparam int DEPTH = NUM_ROW * NUM_COL,
  localparam int ADDR_WIDTH = $clog2(DEPTH)
  )(
  input logic clk,
  input logic rst,
  input logic player_x[10:0],
  input logic player_y[9:0],
  output logic obstacles[3:0], // up, down, left, right
  output logic [ADDR_WIDTH-1:0] map_addr
);
  // get coordinate of player in map
  logic [3:0] blockpos_row;
  logic [4:0] blockpos_col;
  always_comb begin
    blockpos_col = player_x / 32;
    blockpos_row = player_y / 32;
  end

  // cycle through each direction
  logic [1:0] cnt;
  always_ff @(posedge clk) begin
    if (rst) begin
      cnt <= '0;
    end else begin
      cnt <= cnt + 1;
    end
  end

  // calculate map address for each direction
  always_comb begin
    case (cnt)
      2'b00: begin // up
        if (blockpos_row == 0) begin
          map_addr = '0; // out of bounds
        end else begin
          map_addr = (blockpos_row - 1) * NUM_COL + blockpos_col;
        end
      end
      2'b01: begin // down
        if (blockpos_row == NUM_ROW - 1) begin
          map_addr = '0; // out of bounds
        end else begin
          map_addr = (blockpos_row + 1) * NUM_COL + blockpos_col;
        end
      end
      2'b10: begin // left
        if (blockpos_col == 0) begin
          map_addr = '0; // out of bounds
        end else begin
          map_addr = blockpos_row * NUM_COL + (blockpos_col - 1);
        end
      end
      2'b11: begin // right
        if (blockpos_col == NUM_COL - 1) begin
          map_addr = '0; // out of bounds
        end else begin
          map_addr = blockpos_row * NUM_COL + (blockpos_col + 1);
        end
      end
      default: map_addr = '0;
    endcase
  end

  // check obstacles based on map data
  // NOTE: 00 is free space, anything else is an obstacle
  logic [3:0] end_of_block;
  assign end_of_block[0] = (player_y % 32 == 0);  // up
  assign end_of_block[1] = (player_y % 32 == 31); // down
  assign end_of_block[2] = (player_x % 32 == 0);  // left
  assign end_of_block[3] = (player_x % 32 == 31); // right
  always_comb begin
    case (cnt)
      2'b00: obstacles[0] = (map_mem_in != 2'b00) & end_of_block[0]; // up
      2'b01: obstacles[1] = (map_mem_in != 2'b00) & end_of_block[1]; // down
      2'b10: obstacles[2] = (map_mem_in != 2'b00) & end_of_block[2]; // left
      2'b11: obstacles[3] = (map_mem_in != 2'b00) & end_of_block[3]; // right
      default: obstacles = '0;
    endcase
  end

endmodule
