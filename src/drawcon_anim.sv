`timescale 1ns / 1ps

`include "bomberman_dir.svh"

// Animation frame driver for drawcon.
module drawcon_anim #(
    parameter int WALK_ANIM_TIME            = 10,
    parameter int WALK_FRAMES_PER_DIR       = 3,
    parameter int DEST_FRAME_TIME           = 10,
    parameter int DEST_FRAMES               = 6,
    parameter int BOMB_TOTAL_ANIMATION_TIME = 180,
    parameter int BOMB_ANIM_TIME            = 20,
    parameter int P_UP_FRAME_TIME           = 30
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       tick,
    input  logic       game_over,
    input  dir_t       player_1_dir,
    input  dir_t       player_2_dir,
    input  logic       explode_signal,
    input  logic       explode_signal_2,
    output logic [1:0] walk_frame_1,
    output logic [1:0] walk_frame_2,
    output logic [2:0] dest_frame,
    output logic [2:0] bomb_frame,
    output logic       p_up_frame
);

  logic [5:0] frame_cnt;
  logic [5:0] dest_frame_cnt;
  logic [7:0] bomb_frame_cnt;

  always_ff @(posedge clk) begin
    if (rst || game_over) begin
      frame_cnt      <= 6'd0;
      walk_frame_1   <= 2'd0;
      walk_frame_2   <= 2'd0;
      dest_frame_cnt <= 6'd0;
      dest_frame     <= 3'd0;
      bomb_frame_cnt <= 8'd0;
      bomb_frame     <= 3'd0;
      p_up_frame     <= 1'b0;
    end else if (tick) begin
      frame_cnt <= frame_cnt + 1;
      if (frame_cnt == 6'd59) frame_cnt <= 0;

      if (player_1_dir != DIR_NONE) begin
        if ((frame_cnt + 1) % WALK_ANIM_TIME == 0) begin
          walk_frame_1 <= walk_frame_1 + 1;
          if (walk_frame_1 == WALK_FRAMES_PER_DIR - 1) walk_frame_1 <= 0;
        end
      end

      if (player_2_dir != DIR_NONE) begin
        if ((frame_cnt + 1) % WALK_ANIM_TIME == 0) begin
          walk_frame_2 <= walk_frame_2 + 1;
          if (walk_frame_2 == WALK_FRAMES_PER_DIR - 1) walk_frame_2 <= 0;
        end
      end

      if (explode_signal || explode_signal_2) begin
        dest_frame_cnt <= dest_frame_cnt + 1;
        if ((dest_frame_cnt + 1) % DEST_FRAME_TIME == 0) dest_frame <= dest_frame + 1;
        if (dest_frame_cnt == 6'd59) begin
          dest_frame_cnt <= 6'd0;
          dest_frame     <= 3'd0;
        end
      end else begin
        dest_frame_cnt <= 6'd0;
        dest_frame     <= 3'd0;
      end

      p_up_frame <= (frame_cnt < P_UP_FRAME_TIME) ? 1'b0 : 1'b1;

      bomb_frame_cnt <= (bomb_frame_cnt == BOMB_TOTAL_ANIMATION_TIME - 1) ?
                        8'd0 : bomb_frame_cnt + 1;

      unique case (bomb_frame_cnt / BOMB_ANIM_TIME)
        4'd0, 4'd3: bomb_frame <= 3'd0;
        4'd1, 4'd4: bomb_frame <= 3'd1;
        4'd2, 4'd5: bomb_frame <= 3'd2;
        4'd6:       bomb_frame <= 3'd3;
        4'd7:       bomb_frame <= 3'd4;
        4'd8:       bomb_frame <= 3'd5;
      endcase
    end
  end

endmodule
