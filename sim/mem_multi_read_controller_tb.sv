`timescale 1ns/1ps

module mem_multi_read_controller_tb;

    // Parameters
    localparam int NUM_READERS = 8;
    localparam int NUM_ROW     = 11;
    localparam int NUM_COL     = 19;
    localparam int DEPTH       = NUM_ROW * NUM_COL;
    localparam int ADDR_WIDTH  = $clog2(DEPTH);

    // DUT signals
    logic clk;
    logic rst;
    logic [NUM_READERS-1:0] read_req;
    logic [ADDR_WIDTH-1:0]  read_addr_req [0:NUM_READERS-1];
    logic [ADDR_WIDTH-1:0]  read_addr;
    logic [NUM_READERS-1:0] read_granted;

    // Instantiate DUT
    mem_multi_read_controller dut (
        .clk(clk),
        .rst(rst),
        .read_req(read_req),
        .read_addr_req(read_addr_req),
        .read_addr(read_addr),
        .read_granted(read_granted)
    );

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
        read_req = '0;

        // Initialize read addresses
        for (int i = 0; i < NUM_READERS; i++)
            read_addr_req[i] = i * 10;

        #20;
        rst = 0;
        print_status("After reset");

        // ============================================================
        // TEST 1: Single request from reader 0
        // ============================================================
        $display("\nTEST 1: Request from reader 0 only");
        read_req[0] = 1;
        #20;
        print_status("Reader0 granted");

        // Release request
        read_req[0] = 0;
        #20;
        print_status("Reader0 released");

        // ============================================================
        // TEST 2: Single request from reader 1
        // ============================================================
        $display("\nTEST 2: Request from reader 1 only");
        read_req[1] = 1;
        #20;
        print_status("Reader1 granted");

        read_req[1] = 0;
        #20;
        print_status("Reader1 released");

        // ============================================================
        // TEST 3: Both readers 0 and 1 request at the same time — test round robin
        // ============================================================
        $display("\nTEST 3: Readers 0 and 1 request simultaneously — test idx toggle");

        // First simultaneous request
        read_req = '0;
        read_req[0] = 1;
        read_req[1] = 1;
        #20;
        print_status("First simultaneous grant");

        // Release whichever was granted
        read_req[0] = 0;
        read_req[1] = 0;

        #30;
        print_status("After release (idx should toggle)");

        // Second simultaneous request
        read_req[0] = 1;
        read_req[1] = 1;
        #20;
        print_status("Second simultaneous grant (should alternate)");

        // Release again
        if (read_granted[0]) read_req[0] = 0;
        else read_req[1] = 0;

        #30;
        print_status("After second release");

        // ============================================================
        // TEST 4: Longer alternating sequence
        // ============================================================
        $display("\nTEST 4: 4 consecutive simultaneous requests");

        repeat (4) begin
            read_req[0] = 1;
            read_req[1] = 1;
            #20;
            print_status("Simultaneous grant");

            // release the granted one
            read_req[0] = 0;
            read_req[1] = 0;

            #20;
            print_status("After release");
        end

        // End simulation
        $display("\nSimulation complete.\n");
        #20;
        $finish;
    end

endmodule
