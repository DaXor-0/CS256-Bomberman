`timescale 1ns / 1ps


module multidigit (
    input logic clk,
    input logic rst,
    input logic [3:0] dig0,
    input logic [3:0] dig1,
    input logic [3:0] dig2,
    input logic [3:0] dig3,
    input logic [3:0] dig4,
    input logic [3:0] dig5,
    input logic [3:0] dig6,
    input logic [3:0] dig7,
    output logic a,
    output logic b,
    output logic c,
    output logic d,
    output logic e,
    output logic f,
    output logic g,
    output logic [7:0] an
);

  logic [16:0] clock_divider;
  logic [ 2:0] counter;
  logic [ 3:0] dig;

  // Divide the input clock down and use the wrap event as a scan enable.
  always_ff @(posedge clk) begin
    if (rst) begin
      clock_divider <= '0;
      counter <= 3'd0;
    end else begin
      clock_divider <= clock_divider + 1;
      if (clock_divider == 17'h1_FFFF) counter <= counter + 3'd1;
    end
  end

  // 7seg instantiations
  sevenseg s0 (
      .num(dig),
      .a  (a),
      .b  (b),
      .c  (c),
      .d  (d),
      .e  (e),
      .f  (f),
      .g  (g)
  );

  always_comb begin
    unique case (counter)
      3'd0: begin
        an  = 8'b11111110;
        dig = dig0;
      end
      3'd1: begin
        an  = 8'b11111101;
        dig = dig1;
      end
      3'd2: begin
        an  = 8'b11111011;
        dig = dig2;
      end
      3'd3: begin
        an  = 8'b11110111;
        dig = dig3;
      end
      3'd4: begin
        an  = 8'b11101111;
        dig = dig4;
      end
      3'd5: begin
        an  = 8'b11011111;
        dig = dig5;
      end
      3'd6: begin
        an  = 8'b10111111;
        dig = dig6;
      end
      3'd7: begin
        an  = 8'b01111111;
        dig = dig7;
      end
    endcase
  end

endmodule
