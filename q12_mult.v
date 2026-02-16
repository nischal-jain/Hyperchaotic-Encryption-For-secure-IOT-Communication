`timescale 1ns / 1ps
module q12_mult (
    input  signed [23:0] a,
    input  signed [23:0] b,
    output signed [23:0] y
);
    // 24-bit * 24-bit = 48-bit result
    wire signed [47:0] prod = a * b;
    // Shift right by 12 to keep Q12.12 scale
    assign y = prod[35:12];
endmodule