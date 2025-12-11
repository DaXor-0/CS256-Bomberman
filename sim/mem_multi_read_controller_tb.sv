`timescale 1ns/1ps

module mem_multi_read_controller_tb;

    // Parameters
    localparam int NUM_READERS = 8;
    localparam int NUM_ROW     = 11;
    localparam int NUM_COL     = 19;
    localparam int DEPTH       = NUM_ROW * NUM_COL;
    localparam int ADDR_WIDTH  = $clog2(DEPTH);
    localparam int MAP_MEM_WIDTH = 2;

    // DUT signals
    logic clk;
    logic rst;
    logic [NUM_READERS-1:0] read_req;
    logic [ADDR_WIDTH-1:0]  read_addr_req [0:NUM_READERS-1];
    logic [ADDR_WIDTH-1:0]  read_addr;
    logic [NUM_READERS-1:0] read_granted;
    logic [MAP_MEM_WIDTH-1:0] map_mem_in;
    logic [MAP_MEM_WIDTH-1:0] map_mem [0:DEPTH-1];
    logic game_over;
    logic obstacles_valid1, obstacles_valid2;


    // Instantiate DUT
    mem_multi_read_controller dut (
        .clk(clk),
        .rst(rst),
        .game_over(game_over),
        .read_req(read_req),
        .read_addr_req(read_addr_req),
        .read_addr(read_addr),
        .read_granted(read_granted)
    );

    // Two Checkers
    check_obst #(
        .NUM_ROW(NUM_ROW),
        .NUM_COL(NUM_COL)
    ) checker0 (
        .clk(clk),
        .rst(rst),
        .player_x(11'h40),
        .player_y(10'h40),
        .map_mem_in(map_mem_in),
        .read_granted(read_granted[0]),
        .read_req(read_req[0]),
        .map_addr(read_addr_req[0]),
        .obstacles_valid(obstacles_valid1)
    );

    check_obst #(
        .NUM_ROW(NUM_ROW),
        .NUM_COL(NUM_COL)
    ) checker1 (
        .clk(clk),
        .rst(rst),
        .player_x(11'd1088),
        .player_y(10'd576),
        .map_mem_in(map_mem_in),
        .read_granted(read_granted[1]),
        .read_req(read_req[1]),
        .map_addr(read_addr_req[1]),
        .obstacles_valid(obstacles_valid2)
    );
    

    // Load map
    initial begin
      $readmemh("maps/basic_map.mem", map_mem);
    end

    always_ff @(posedge clk) begin
    if (rst) begin
      map_mem_in <= '0;
    end else begin
      map_mem_in <= map_mem[read_addr];
    end
    end

    // Clock
    always #5 clk = ~clk;

    // Helpers
    task print_status(string label);
        $display("[%0t] %s | read_req=%b | granted=%b | addr=%0d | idx=%0d",
            $time, label, read_req, read_granted, read_addr, dut.idx);
    endtask

    initial begin
        // Initial conditions
        clk = 0;
        rst = 1;
        game_over = 0;
        read_req = '0;

        // Initialize read addresses
        for (int i = 2; i < NUM_READERS; i++)
            read_addr_req[i] = i * 10;

        #20;
        rst = 0;
        print_status("After reset");

        // ============================================================
        // TEST 1: Single request from reader 0
        // ============================================================
//        $display("\nTEST 1: Request from reader 0 only");
//        read_req[0] = 1;
//        #20;
//        print_status("Reader0 granted");

//        // Release request
//        read_req[0] = 0;
//        #20;
//        print_status("Reader0 released");

//        // ============================================================
//        // TEST 2: Single request from reader 1
//        // ============================================================
//        $display("\nTEST 2: Request from reader 1 only");
//        read_req[1] = 1;
//        #20;
//        print_status("Reader1 granted");

//        read_req[1] = 0;
//        #20;
//        print_status("Reader1 released");

//        // ============================================================
//        // TEST 3: Both readers 0 and 1 request at the same time — test round robin
//        // ============================================================
//        $display("\nTEST 3: Readers 0 and 1 request simultaneously — test idx toggle");

//        // First simultaneous request
//        read_req = '0;
//        read_req[0] = 1;
//        read_req[1] = 1;
//        #20;
//        print_status("First simultaneous grant");

//        // Release whichever was granted
//        read_req[0] = 0;
//        read_req[1] = 0;

//        #30;
//        print_status("After release (idx should toggle)");

//        // Second simultaneous request
//        read_req[0] = 1;
//        read_req[1] = 1;
//        #20;
//        print_status("Second simultaneous grant (should alternate)");

//        // Release again
//        if (read_granted[0]) read_req[0] = 0;
//        else read_req[1] = 0;

//        #30;
//        print_status("After second release");

//        // ============================================================
        // TEST 4: Longer alternating sequence
        // ============================================================
//        $display("\nTEST 4: 4 consecutive simultaneous requests");

//        repeat (8) begin
//            read_req[0] = 1;
//            read_req[1] = 1;
//            #20;
//            print_status("Simultaneous grant");

//            // release the granted one
//            read_req[0] = 0;
//            read_req[1] = 0;

//            #20;
//            print_status("After release");
//        end

//        // End simulation
//        $display("\nSimulation complete.\n");
//        #20;
//        $finish;
    end

endmodule
