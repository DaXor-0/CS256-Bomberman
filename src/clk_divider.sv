`timescale 1ns / 1ps

// MODULE Generated using ChatGPT.
module clk_divider #(
    parameter int INPUT_FREQ_HZ  = 6_000_000, // input clock frequency
    parameter int OUTPUT_FREQ_HZ = 60          // desired output frequency
)(
    input  logic clk_in,   // input clock
    output logic clk_out   // divided clock output
);

    // Derived parameters
    localparam int DIVISOR     = INPUT_FREQ_HZ / OUTPUT_FREQ_HZ;
    localparam int HALF_PERIOD = DIVISOR / 2;   // toggle every half period

    // Counter width: enough bits to count up to HALF_PERIOD
    localparam int COUNTER_WIDTH = $clog2(HALF_PERIOD);

    logic [COUNTER_WIDTH-1:0] counter = 0;
    logic clk_out_reg = 0;

    assign clk_out = clk_out_reg;

    always_ff @(posedge clk_in) begin
        if (counter == HALF_PERIOD - 1) begin
            counter <= 0;
            clk_out_reg <= ~clk_out_reg; // toggle output
        end else begin
            counter <= counter + 1;
        end
    end

endmodule
