`timescale 1ns/1ps

module player_controller_tb;
  localparam CLK_PERIOD = 10;
  localparam int TICK_DIV = 8;
  localparam int TOTAL_TICKS = 10000;
  localparam int OBSTACLE_PERIOD = 64;

  // Clock/reset
  logic clk = 0;
  logic rst = 1;

  // Stimulus inputs
  logic tick = 0;
  logic up = 0, down = 0, left = 0, right = 0;
  logic obstacle_up = 0, obstacle_down = 0, obstacle_left = 0, obstacle_right = 0;

  // Outputs
  logic [10:0] blkpos_x;
  logic [9:0]  blkpos_y;
  int unsigned tick_div_ctr = 0;

  player_controller #(
      .INIT_X(800),
      .INIT_Y(400),
      .STEP_SIZE(4)
  ) dut (
      .clk(clk),
      .rst(rst),
      .tick(tick),
      .up(up),
      .down(down),
      .left(left),
      .right(right),
      .obstacle_up(obstacle_up),
      .obstacle_down(obstacle_down),
      .obstacle_left(obstacle_left),
      .obstacle_right(obstacle_right),
      .blkpos_x(blkpos_x),
      .blkpos_y(blkpos_y)
  );

  // Clock generation
  always #(CLK_PERIOD/2) clk = ~clk;

  // Derive a single-cycle tick from the clock to mimic the frame strobe.
  always_ff @(posedge clk) begin
    if (rst) begin
      tick <= 1'b0;
      tick_div_ctr <= 0;
    end else begin
      tick <= 1'b0;
      if (tick_div_ctr == TICK_DIV - 1) begin
        tick <= 1'b1;
        tick_div_ctr <= 0;
      end else begin
        tick_div_ctr <= tick_div_ctr + 1;
      end
    end
  end

  task automatic wait_for_tick(string tag, int unsigned repeat_count = 1);
    for (int unsigned idx = 0; idx < repeat_count; idx++) begin
      @(posedge tick);
      #1;
      if (repeat_count > 1) begin
        $display("[%0t] %s #%0d -> pos=(%0d,%0d)", $time, tag, idx + 1, blkpos_x, blkpos_y);
      end else begin
        $display("[%0t] %s -> pos=(%0d,%0d)", $time, tag, blkpos_x, blkpos_y);
      end
    end
  endtask

  initial begin
    $dumpfile("player_controller_tb.vcd");
    $dumpvars(0, player_controller_tb);

    // Hold reset for a few cycles
    repeat (3) @(posedge clk);
    rst = 0;

    for (int tick_idx = 0; tick_idx < TOTAL_TICKS; tick_idx++) begin
      if (tick_idx % OBSTACLE_PERIOD == 0) begin
        logic [3:0] obstacle_bits;
        obstacle_bits = $urandom_range(0, 4'hF);
        {obstacle_up, obstacle_down, obstacle_left, obstacle_right} = obstacle_bits;
      end

      {up, down, left, right} = 4'b0;
      unique case ($urandom_range(0, 4))
        1: up    = 1'b1;
        2: down  = 1'b1;
        3: left  = 1'b1;
        4: right = 1'b1;
        default:;
      endcase

      wait_for_tick($sformatf(
          "tick %0d cmd(U/D/L/R)=%0d%0d%0d%0d obs=%0d%0d%0d%0d",
          tick_idx + 1,
          up, down, left, right,
          obstacle_up, obstacle_down, obstacle_left, obstacle_right
      ));
    end

    {up, down, left, right} = 4'b0;
    {obstacle_up, obstacle_down, obstacle_left, obstacle_right} = 4'b0;

    repeat (1000) @(posedge clk);
    $finish;
  end

endmodule
