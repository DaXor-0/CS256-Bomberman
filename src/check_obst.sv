`timescale 1ns / 1ps
/*
* Module: check_obst
* Description: Check for obstacles around a player sprite in a tile map.
* Updated: Added obstacles_valid signal for 4-cycle round-robin completion
* */
module check_obst #(
  parameter int NUM_ROW   = 11,
  parameter int NUM_COL   = 19,
  parameter int TILE_PX   = 64,
  parameter int SPRITE_W  = 32,
  parameter int SPRITE_H  = 64,

  localparam int TILE_SHIFT = $clog2(TILE_PX),
  localparam int DEPTH      = NUM_ROW * NUM_COL,
  localparam int ADDR_WIDTH = $clog2(DEPTH)
)(
  input  logic                  clk,
  input  logic                  rst,

  input  logic [10:0]           player_x,     // pixel coords in logic map
  input  logic [9:0]            player_y,
  input  logic [1:0]            map_mem_in,   // BRAM/ROM data (1-cycle after addr)

  output logic [3:0]            obstacles,    // [0]=up,[1]=down,[2]=left,[3]=right
  output logic [ADDR_WIDTH-1:0] map_addr,     // BRAM/ROM address
  output logic [TILE_SHIFT:0]   obstacle_dist [3:0], // distance (px) to next obstacle or max if none
  output logic                  obstacles_valid      // HIGH when all 4 directions checked
);

  // Direction indices
  localparam int UP    = 0;
  localparam int DOWN  = 1;
  localparam int LEFT  = 2;
  localparam int RIGHT = 3;

  // ==========================================================================
  // Tile coordinates (64 px per tile -> shift by 6)
  // ==========================================================================
  // player_x/y are the sprite's TOP-LEFT corner
  logic [$clog2(NUM_ROW)-1:0] blockpos_row;
  logic [$clog2(NUM_COL)-1:0] blockpos_col;
  assign blockpos_row = (player_y >> TILE_SHIFT); // truncates to ROW_W
  assign blockpos_col = (player_x >> TILE_SHIFT); // truncates to COL_W

  // ===========================================================================
  // End-of-block (EOB) conditions for a 32x64 sprite on 64x64 tiles
  // ===========================================================================
  // Vertical: y lower bits == 0.
  // Right boundary when right edge aligns with tile boundary or sprite width.
  logic [3:0] eob;

  // Map edge_block flags (prevent OOB addressing)
  logic [3:0] edge_block;
  always_comb begin
    edge_block[UP]    = (blockpos_row == 0);
    edge_block[DOWN]  = (blockpos_row == NUM_ROW-1);
    edge_block[LEFT]  = (blockpos_col == 0);
    edge_block[RIGHT] = (blockpos_col == NUM_COL-1);
  end

  // ==========================================================================
  // Distance to the next tile boundary for each direction (in pixels)
  // ==========================================================================
  localparam logic [TILE_SHIFT:0] MAX_DIST = '1;

  logic [TILE_SHIFT:0] tile_offset_x;
  logic [TILE_SHIFT:0] tile_offset_y;
  logic [TILE_SHIFT:0] right_edge_offset;
  logic [TILE_SHIFT:0] bottom_edge_offset;
  assign tile_offset_x = {1'b0, player_x[TILE_SHIFT-1:0]};
  assign tile_offset_y = {1'b0, player_y[TILE_SHIFT-1:0]};
  // FIX [P0]: Keep SPRITE_W and SPRITE_H at full TILE_SHIFT+1 bits to avoid truncation
  assign right_edge_offset = tile_offset_x + (TILE_SHIFT+1)'(SPRITE_W);
  assign bottom_edge_offset = tile_offset_y + (TILE_SHIFT+1)'(SPRITE_H);

  logic [TILE_SHIFT:0] dist_next [3:0];
  always_comb begin
    eob[UP]    = (tile_offset_y == 0);
    eob[DOWN]  = (bottom_edge_offset >= TILE_PX);
    eob[LEFT]  = (tile_offset_x == 0);
    eob[RIGHT] = (right_edge_offset >= TILE_PX);

    dist_next[LEFT]  = tile_offset_x;
    dist_next[UP]    = tile_offset_y;
    dist_next[RIGHT] = (right_edge_offset >= TILE_PX)
                       ? '0 : (TILE_PX - right_edge_offset);
    dist_next[DOWN]  = (bottom_edge_offset >= TILE_PX)
                       ? '0 : (TILE_PX - bottom_edge_offset);
  end

  // ===========================================================================
  // Direction counter (iterates through UP/DOWN/LEFT/RIGHT)
  // ===========================================================================
  logic [1:0] dir_cnt;
  always_ff @(posedge clk) begin
    if (rst) dir_cnt <= 2'd0;
    else     dir_cnt <= dir_cnt + 2'd1;
  end

  // ===========================================================================
  // Valid signal: HIGH when all 4 directions have been checked
  // ===========================================================================
  always_ff @(posedge clk) begin
    if (rst) 
      obstacles_valid <= 1'b0;
    else
      // Assert when dir_cnt == 0, meaning we just finished writing RIGHT (dir=3)
      obstacles_valid <= (dir_cnt == 2'b00);
  end

  // ===========================================================================
  // Stage A: compute address & capture context for the current direction
  // ===========================================================================
  logic [ADDR_WIDTH-1:0] map_addr_a;
  logic [1:0]            dir_a;
  logic [3:0]            edge_block_a, eob_a;
  logic [TILE_SHIFT:0]   dist_a;
  always_ff @(posedge clk) begin
    if (rst) begin
      dir_a         <= 2'd0;
      edge_block_a  <= '0;
      eob_a         <= '0;
      map_addr_a    <= '0;
      dist_a        <= '0;
    end else begin
      dir_a         <= dir_cnt; // capture the direction used for this addr
      edge_block_a  <= edge_block;
      eob_a         <= eob;
      dist_a        <= dist_next[dir_cnt];

      // Default to 0 when out-of-bounds; only form address when valid.
      case (dir_cnt)
        2'b00:  map_addr_a <= edge_block[UP]
                              ? '0 : ( (blockpos_row - 1) * NUM_COL + blockpos_col );
        2'b01:  map_addr_a <= edge_block[DOWN]
                              ? '0 : ( (blockpos_row + 1) * NUM_COL + blockpos_col );
        2'b10:  map_addr_a <= edge_block[LEFT]
                              ? '0 : ( blockpos_row       * NUM_COL + (blockpos_col - 1) );
        2'b11:  map_addr_a <= edge_block[RIGHT]
                              ? '0 : ( blockpos_row       * NUM_COL + (blockpos_col + 1) );
      endcase
    end
  end

  // Drive memory address (assumes 1-cycle synchronous read)
  always_ff @(posedge clk) begin
    if (rst) map_addr <= '0;
    else     map_addr <= map_addr_a;
  end

  // ===========================================================================
  // Stage B: data returns; update exactly one obstacle bit per cycle
  // ===========================================================================
  // Keep previous bits for directions not being updated this cycle.
  always_ff @(posedge clk) begin
    if (rst) begin
      obstacles     <= '0;
      obstacle_dist[UP]    <= MAX_DIST;
      obstacle_dist[DOWN]  <= MAX_DIST;
      obstacle_dist[LEFT]  <= MAX_DIST;
      obstacle_dist[RIGHT] <= MAX_DIST;
    end else begin
      // Block only if we're crossing a tile boundary (eob_a)
      // and either: (a) we're at the map edge, or (b) the neighbor tile is non-empty.
      obstacles[dir_a] <= eob_a[dir_a] & ( edge_block_a[dir_a] | (map_mem_in != 2'b00) );

      // Distance to obstacle: when blocked, clamp to remaining pixels in tile;
      // otherwise present a large value so the controller is unconstrained.
      obstacle_dist[dir_a] <= (edge_block_a[dir_a] | (map_mem_in != 2'b00)) ? dist_a : MAX_DIST;
    end
  end

endmodule
