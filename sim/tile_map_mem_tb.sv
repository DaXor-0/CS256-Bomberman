`timescale 1ns/1ps

module map_mem_tb;
  localparam CLK_PERIOD = 10;

  logic clk = 0;
  logic rst = 1;
  logic [7:0]  rd_addr;
  logic [3:0]  rd_data;
  logic        we;
  logic [7:0]  wr_addr;
  logic [3:0]  wr_data;

  tile_map_mem #(
      .NUM_ROW(11),
      .NUM_COL(19),
      .DATA_WIDTH(4),
      .MEM_INIT_FILE("maps/basic_map.mem")
  ) dut (
      .clk(clk),
      .rst(rst),
      .rd_addr(rd_addr),
      .rd_data(rd_data),
      .we(we),
      .wr_addr(wr_addr),
      .wr_data(wr_data)
  );

  always #(CLK_PERIOD/2) clk = ~clk;

  initial begin
    $dumpfile("map_mem_tb.vcd");
    $dumpvars(0, tile_map_mem_tb);

    rd_addr = 0;
    wr_addr = 0;
    wr_data = 0;
    we      = 0;

    repeat (3) @(posedge clk);
    rst = 0;

    // Sample a few addresses from the default map
    for (int idx = 1; idx <= 20; idx++) begin
      rd_addr = idx[7:0];
      @(posedge clk);
      $display("[%0t] read addr=%0d -> data=%0h", $time, rd_addr, rd_data);
    end

    // Demonstrate a write and subsequent readback
    wr_addr = 8'd19;
    wr_data = 4'hE;
    we      = 1'b1;
    @(posedge clk);
    we      = 1'b0;

    rd_addr = 8'd19;
    @(posedge clk);
    $display("[%0t] after write addr=19 -> data=%0h", $time, rd_data);

    repeat (10) @(posedge clk);
    $finish;
  end

endmodule
