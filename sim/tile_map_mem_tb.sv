`timescale 1ns/1ps

module map_mem_tb;
  localparam CLK_PERIOD = 10;
  localparam int NUM_ROW = 11;
  localparam int NUM_COL = 19;
  localparam int DATA_WIDTH = 2;
  localparam int DEPTH = NUM_ROW * NUM_COL;
  localparam int ADDR_WIDTH = $clog2(DEPTH);

  logic clk = 0;
  logic rst = 1;
  logic game_over = 0;
  logic [ADDR_WIDTH-1:0] rd_addr_1, rd_addr_2;
  logic [DATA_WIDTH-1:0] rd_data_1, rd_data_2;
  logic we;
  logic [ADDR_WIDTH-1:0] wr_addr;
  logic [DATA_WIDTH-1:0] wr_data;

  map_mem #(
      .NUM_ROW(NUM_ROW),
      .NUM_COL(NUM_COL),
      .DATA_WIDTH(DATA_WIDTH),
      .MEM_INIT_FILE("maps/basic_map.mem")
  ) dut (
      .clk(clk),
      .rst(rst),
      .game_over(game_over),
      .rd_addr_1(rd_addr_1),
      .rd_data_1(rd_data_1),
      .rd_addr_2(rd_addr_2),
      .rd_data_2(rd_data_2),
      .we(we),
      .wr_addr(wr_addr),
      .wr_data(wr_data)
  );

  always #(CLK_PERIOD/2) clk = ~clk;

  // Keep RNG deterministic for test
  initial begin
    force dut.place_dest_blk = 1'b0;
  end

  initial begin
    $dumpfile("map_mem_tb.vcd");
    $dumpvars(0, map_mem_tb);

    rd_addr_1 = '0;
    rd_addr_2 = '0;
    wr_addr = '0;
    wr_data = '0;
    we      = 0;

    repeat (3) @(posedge clk);
    rst = 0;

    // Sample a few addresses from the default map
    for (int idx = 0; idx < 20; idx++) begin
      rd_addr_1 = idx[ADDR_WIDTH-1:0];
      @(posedge clk); // read latency
      $display("[%0t] read addr=%0d -> data=%0h", $time, rd_addr_1, rd_data_1);
    end

    // Demonstrate a write and subsequent readback
    wr_addr = 8'd19;
    wr_data = 2'h3;
    we      = 1'b1;
    @(posedge clk);
    we      = 1'b0;

    rd_addr_1 = 8'd19;
    @(posedge clk);
    $display("[%0t] after write addr=19 -> data=%0h", $time, rd_data_1);

    repeat (10) @(posedge clk);
    $finish;
  end

endmodule
