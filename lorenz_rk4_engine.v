// lorenz_rk4_engine.v
// Implements the iterative RK4 solver for the 4D Lorenz Hyperchaotic System.

`include "config.vh"

module lorenz_rk4_engine (
    input  wire                 clk,
    input  wire                 rst,
    output wire [`DATA_WIDTH-1:0] x_out,
    output wire [`DATA_WIDTH-1:0] y_out,
    output wire [`DATA_WIDTH-1:0] z_out,
    output wire [`DATA_WIDTH-1:0] w_out,
    output wire                  state_valid 
);

localparam INT_WIDTH = `INT_WIDTH;

reg signed [`DATA_WIDTH-1:0] x_reg, y_reg, z_reg, w_reg;

// Fixed-Point Constants (Q12.12 format)
// A = 10 (10.0), B = 28 (28.0), D = 1 (1.0)
localparam signed [`DATA_WIDTH-1:0] A_PARAM   = {12'd10, {`FRAC_WIDTH{1'b0}}};     
localparam signed [`DATA_WIDTH-1:0] B_PARAM   = {12'd28, {`FRAC_WIDTH{1'b0}}};     
// C = 8/3 ≈ 2.666... (0010 1010 1010 1010 1010 1011)
localparam signed [`DATA_WIDTH-1:0] C_PARAM   = 24'h002AAA;                       
localparam signed [`DATA_WIDTH-1:0] D_PARAM   = {12'd1, {`FRAC_WIDTH{1'b0}}};     
// DT (Step Size) = 0.001 (0000 0000 0000 0000 0010 1001)
localparam signed [`DATA_WIDTH-1:0] DT_PARAM  = 24'h000029;                         
// 1/6 ≈ 0.1666... (0000 0000 0000 0010 1010 1011)
localparam signed [`DATA_WIDTH-1:0] ONE_SIXTH = 24'h0002AB;                       

// Initial Conditions X=Y=Z=W=1.0
localparam signed [`DATA_WIDTH-1:0] X_INIT = {12'd1, {`FRAC_WIDTH{1'b0}}}; 
localparam signed [`DATA_WIDTH-1:0] Y_INIT = X_INIT;
localparam signed [`DATA_WIDTH-1:0] Z_INIT = X_INIT;
localparam signed [`DATA_WIDTH-1:0] W_INIT = X_INIT;

// FSM States for RK4 Multi-Cycle Processing
reg [2:0] state;
localparam S_IDLE=3'd0, S_CALC_K1=3'd1, S_CALC_K2=3'd2, S_CALC_K3=3'd3, S_CALC_K4=3'd4, S_COMBINE=3'd5;

// Registers to store K-values (k = dt * f)
reg signed [`DATA_WIDTH-1:0] k1x, k1y, k1z, k1w, k2x, k2y, k2z, k2w;
reg signed [`DATA_WIDTH-1:0] k3x, k3y, k3z, k3w, k4x, k4y, k4z, k4w;

// Wires for current state inputs to the derivative function
wire signed [`DATA_WIDTH-1:0] x_deriv_in, y_deriv_in, z_deriv_in, w_deriv_in;
// Wires for derivative function outputs (f(x,y,z,w))
wire signed [`DATA_WIDTH-1:0] fx, fy, fz, fw;
// Wires for intermediate products
wire signed [`DATA_WIDTH-1:0] prod_aymx, prod_bx, prod_xz, prod_xy, prod_cz, prod_dx;
// Wires for delta T * f (i.e., the K-values before assignment)
wire signed [`DATA_WIDTH-1:0] dt_fx, dt_fy, dt_fz, dt_fw;

// --- A. Derivative Function Logic (F(X,Y,Z,W)) ---
// dx/dt = A(y-x) + w
fxp_mult mult_aymx (.a(A_PARAM), .b(y_deriv_in - x_deriv_in), .y(prod_aymx));
assign fx = prod_aymx + w_deriv_in;

// dy/dt = Bx - y - xz
fxp_mult mult_bx   (.a(B_PARAM), .b(x_deriv_in),              .y(prod_bx));
fxp_mult mult_xz   (.a(x_deriv_in),.b(z_deriv_in),              .y(prod_xz));
assign fy = prod_bx - y_deriv_in - prod_xz;

// dz/dt = xy - Cz
fxp_mult mult_xy   (.a(x_deriv_in),.b(y_deriv_in),              .y(prod_xy));
fxp_mult mult_cz   (.a(C_PARAM), .b(z_deriv_in),              .y(prod_cz));
assign fz = prod_xy - prod_cz;

// dw/dt = -Dx + y
fxp_mult mult_dx   (.a(D_PARAM), .b(x_deriv_in),              .y(prod_dx));
assign fw = -prod_dx + y_deriv_in;

// K = dt * f (This is computed combinatorially in every state)
fxp_mult mult_dt_fx(.a(DT_PARAM), .b(fx), .y(dt_fx));
fxp_mult mult_dt_fy(.a(DT_PARAM), .b(fy), .y(dt_fy));
fxp_mult mult_dt_fz(.a(DT_PARAM), .b(fz), .y(dt_fz));
fxp_mult mult_dt_fw(.a(DT_PARAM), .b(fw), .y(dt_fw));

// --- B. RK4 Step MUXing Logic (Determines which state to use for derivatives) ---
// Note: >>> 1 is an arithmetic right shift by 1, equivalent to dividing by 2.
// X(t + 0.5*k1) for K2, X(t + 0.5*k2) for K3, X(t + k3) for K4
assign x_deriv_in = (state == S_CALC_K2) ? x_reg + (k1x >>> 1) : 
                    (state == S_CALC_K3) ? x_reg + (k2x >>> 1) : 
                    (state == S_CALC_K4) ? x_reg + k3x : x_reg;

assign y_deriv_in = (state == S_CALC_K2) ? y_reg + (k1y >>> 1) : 
                    (state == S_CALC_K3) ? y_reg + (k2y >>> 1) : 
                    (state == S_CALC_K4) ? y_reg + k3y : y_reg;

assign z_deriv_in = (state == S_CALC_K2) ? z_reg + (k1z >>> 1) : 
                    (state == S_CALC_K3) ? z_reg + (k2z >>> 1) : 
                    (state == S_CALC_K4) ? z_reg + k3z : z_reg;

assign w_deriv_in = (state == S_CALC_K2) ? w_reg + (k1w >>> 1) : 
                    (state == S_CALC_K3) ? w_reg + (k2w >>> 1) : 
                    (state == S_CALC_K4) ? w_reg + k3w : w_reg;

// --- C. Summation for Final Update ---
// (k1 + 2*k2 + 2*k3 + k4)
wire signed [`DATA_WIDTH-1:0] rk_sum_x, rk_sum_y, rk_sum_z, rk_sum_w;
assign rk_sum_x = k1x + (k2x << 1) + (k3x << 1) + k4x;
assign rk_sum_y = k1y + (k2y << 1) + (k3y << 1) + k4y;
assign rk_sum_z = k1z + (k2z << 1) + (k3z << 1) + k4z;
assign rk_sum_w = k1w + (k2w << 1) + (k3w << 1) + k4w;

// (1/6) * Sum
wire signed [`DATA_WIDTH-1:0] scaled_update_x, scaled_update_y, scaled_update_z, scaled_update_w;
fxp_mult mult_div6_x (.a(rk_sum_x), .b(ONE_SIXTH), .y(scaled_update_x));
fxp_mult mult_div6_y (.a(rk_sum_y), .b(ONE_SIXTH), .y(scaled_update_y));
fxp_mult mult_div6_z (.a(rk_sum_z), .b(ONE_SIXTH), .y(scaled_update_z));
fxp_mult mult_div6_w (.a(rk_sum_w), .b(ONE_SIXTH), .y(scaled_update_w));

// --- D. Main RK4 Sequential Logic (FSM) ---
always @(posedge clk or posedge rst) begin
    if (rst) begin
        x_reg <= X_INIT; y_reg <= Y_INIT; z_reg <= Z_INIT; w_reg <= W_INIT;
        state <= S_IDLE;
    end else begin
        case (state)
            S_IDLE:      state <= S_CALC_K1;
            S_CALC_K1:   begin k1x <= dt_fx; k1y <= dt_fy; k1z <= dt_fz; k1w <= dt_fw; state <= S_CALC_K2; end
            S_CALC_K2:   begin k2x <= dt_fx; k2y <= dt_fy; k2z <= dt_fz; k2w <= dt_fw; state <= S_CALC_K3; end
            S_CALC_K3:   begin k3x <= dt_fx; k3y <= dt_fy; k3z <= dt_fz; k3w <= dt_fw; state <= S_CALC_K4; end
            S_CALC_K4:   begin k4x <= dt_fx; k4y <= dt_fy; k4z <= dt_fz; k4w <= dt_fw; state <= S_COMBINE; end
            S_COMBINE:   begin
                // Final state update: X_new = X_old + (1/6) * Sum
                x_reg <= x_reg + scaled_update_x;
                y_reg <= y_reg + scaled_update_y;
                z_reg <= z_reg + scaled_update_z;
                w_reg <= w_reg + scaled_update_w;
                state <= S_IDLE;
            end
            default: state <= S_IDLE;
        endcase
    end
end

// --- Module Outputs ---
assign x_out = x_reg;
assign y_out = y_reg;
assign z_out = z_reg;
assign w_out = w_reg;
assign state_valid = (state == S_COMBINE); // Output valid flag for keystream generation

endmodule