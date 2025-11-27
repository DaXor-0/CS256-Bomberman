`timescale 1ns/1ps


module mem_read_controller_tb;
 // ---- Map and tile geometry ----
    parameter int NUM_ROW     = 11;
    parameter int NUM_COL     = 19;
    parameter int TILE_PX     = 64;
    parameter int MAP_MEM_WIDTH = 2;
    parameter int SPRITE_W  = 32;
    parameter int SPRITE_H  = 48;
        

    localparam int DEPTH      = NUM_ROW * NUM_COL;
    localparam int ADDR_WIDTH = $clog2(DEPTH);
    localparam int TILE_SHIFT = $clog2(TILE_PX);
logic clk;
logic rst;
logic [1:0] read_req;
logic [ADDR_WIDTH-1:0] read_addr_req [0:1];
logic [ADDR_WIDTH-1:0] read_addr;
logic [1:0] read_granted;

mem_read_controller
#(
    .NUM_ROW(NUM_ROW),
    .NUM_COL(NUM_COL),
    .TILE_PX(TILE_PX),
    .MAP_MEM_WIDTH(MAP_MEM_WIDTH),
    .SPRITE_W(SPRITE_W),
    .SPRITE_H(SPRITE_H)
) uut (
    .clk(clk),
    .rst(rst),
    .read_req(read_req),
    .read_addr_req(read_addr_req),
    .read_addr(read_addr),
    .read_granted(read_granted)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk; // 10 time units clock period
end

// Test sequence
initial begin
    // Initialize inputs
    rst = 1;
    read_req = 2'b00;
    read_addr_req[0] = '0;
    read_addr_req[1] = '0;
    #15;
    rst = 0;
    #10;
    // Test case 1: Single read request from reader 0
    read_req = 2'b01;
    read_addr_req[0] = 11'd10;
    #20;
    read_req = 2'b00;
    #20;
    // Test case 2: Single read request from reader 1
    read_req = 2'b10;
    read_addr_req[1] = 11'd20;
    #20;
    read_req = 2'b00;
    #20;
    // Test case 3: Simultaneous read requests from both readers
    read_req = 2'b11;
    read_addr_req[0] = 11'd30;
    read_addr_req[1] = 11'd40;
    #20;
    read_req = 2'b01;
    #50;
    // End of simulation
    $stop;
end

endmodule