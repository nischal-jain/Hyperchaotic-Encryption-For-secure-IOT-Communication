`timescale 1ns / 1ps
// Calculates dx, dy, dz, dw for a given state (Q12.12)
module lorenz_core (
    input  signed [23:0] x, y, z, w,
    input  signed [23:0] a, b, c, d,
    output signed [23:0] dx, dy, dz, dw
);
    wire signed [23:0] xy, xz, bx, az, dx_term, dw_term;

    // --- Shared Multipliers (Function Wrappers) ---
    // dx = a * (y - x)
    // dy = b*x - y - x*z + w
    // dz = x*y - c*z
    // dw = -d*x

    // Helper: q12_mult defined internally or externally
    // Assuming q12_mult module exists (see below)

    wire signed [23:0] y_minus_x = y - x;
    
    // Multiplications
    q12_mult m1 (.a(a), .b(y_minus_x), .y(dx)); // dx = a(y-x)
    
    q12_mult m2 (.a(b), .b(x), .y(bx));         // b*x
    q12_mult m3 (.a(x), .b(z), .y(xz));         // x*z
    assign dy = bx - y - xz + w;                // dy calculation
    
    q12_mult m4 (.a(x), .b(y), .y(xy));         // x*y
    q12_mult m5 (.a(c), .b(z), .y(az));         // c*z (using 'az' as temp name)
    assign dz = xy - az;                        // dz calculation
    
    q12_mult m6 (.a(d), .b(x), .y(dw_term));    // d*x
    assign dw = -dw_term;                       // dw = -d*x

endmodule