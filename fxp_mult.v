// fxp_mult.v
// A generic fixed-point multiplier utility.

`include "config.vh"

module fxp_mult (
    input  signed [`DATA_WIDTH-1:0] a,
    input  signed [`DATA_WIDTH-1:0] b,
    output signed [`DATA_WIDTH-1:0] y
);

wire signed [(2*`DATA_WIDTH)-1:0] mult_temp;

assign mult_temp = a * b;

// Scale the result: Shift right by FRAC_WIDTH to convert Q2I.2F back to QI.F.
assign y = mult_temp[ (`DATA_WIDTH - 1) + `FRAC_WIDTH : `FRAC_WIDTH ];

endmodule