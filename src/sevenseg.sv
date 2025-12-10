`timescale 1ns / 1ps

`include "bomberman_dir.svh"

/**
 * Module: sevenseg
 * Description: 4-bit to 7-segment display decoder.
 * Converts a 4-bit binary input into the corresponding 7-segment display signals.
 */
module sevenseg (
    input [3:0] num,
    output logic a,
    output logic b,
    output logic c,
    output logic d,
    output logic e,
    output logic f,
    output logic g
);
  always_comb begin
    case (num)
      4'h0: {a, b, c, d, e, f, g} = SEG_0;  // 0
      4'h1: {a, b, c, d, e, f, g} = SEG_1;  // 1
      4'h2: {a, b, c, d, e, f, g} = SEG_2;  // 2
      4'h3: {a, b, c, d, e, f, g} = SEG_3;  // 3
      4'h4: {a, b, c, d, e, f, g} = SEG_4;  // 4
      4'h5: {a, b, c, d, e, f, g} = SEG_5;  // 5
      4'h6: {a, b, c, d, e, f, g} = SEG_6;  // 6
      4'h7: {a, b, c, d, e, f, g} = SEG_7;  // 7
      4'h8: {a, b, c, d, e, f, g} = SEG_8;  // 8
      4'h9: {a, b, c, d, e, f, g} = SEG_9;  // 9
      4'hA: {a, b, c, d, e, f, g} = SEG_A;  // A
      4'hB: {a, b, c, d, e, f, g} = SEG_B;  // B
      4'hC: {a, b, c, d, e, f, g} = SEG_C;  // C
      4'hD: {a, b, c, d, e, f, g} = SEG_D;  // D
      4'hE: {a, b, c, d, e, f, g} = SEG_E;  // E
      4'hF: {a, b, c, d, e, f, g} = SEG_F;  // F
      default: {a, b, c, d, e, f, g} = SEG_OFF;
    endcase
  end
endmodule

