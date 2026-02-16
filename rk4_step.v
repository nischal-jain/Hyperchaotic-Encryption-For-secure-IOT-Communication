`timescale 1ns / 1ps
module rk4_step (
    input  wire             clk,
    input  wire             rst,
    // State inputs
    input  wire signed [23:0] x_in, y_in, z_in, w_in,
    // Parameters
    input  wire signed [23:0] a, b, c, d, dt,
    // Outputs
    output reg  signed [23:0] x_out, y_out, z_out, w_out,
    output reg                done
);

    // --- State Machine Definitions ---
    localparam [2:0] S_IDLE = 0, S_K1 = 1, S_K2 = 2, S_K3 = 3, S_K4 = 4;
    reg [2:0] state;

    // --- 1/6 Constant (0.1666 in Q12.12) ---
    localparam signed [23:0] INV_6 = 24'h0002AB; 

    // --- Internal Signals ---
    reg signed [23:0] calc_x, calc_y, calc_z, calc_w; // Inputs to lorenz_core
    wire signed [23:0] out_dx, out_dy, out_dz, out_dw; // Outputs from lorenz_core
    
    // Accumulators for the final sum (k1 + 2k2 + 2k3 + k4)
    reg signed [23:0] sum_x, sum_y, sum_z, sum_w;
    
    // Temporaries for K values
    reg signed [23:0] k_x, k_y, k_z, k_w;

    // Instantiate ONE lorenz_core (Reused 4 times)
    lorenz_core core_inst (
        .x(calc_x), .y(calc_y), .z(calc_z), .w(calc_w),
        .a(a), .b(b), .c(c), .d(d),
        .dx(out_dx), .dy(out_dy), .dz(out_dz), .dw(out_dw)
    );

    // Multiply helper for DT scaling (k = deriv * dt)
    wire signed [23:0] k_x_next, k_y_next, k_z_next, k_w_next;
    q12_mult mdt_x (.a(out_dx), .b(dt), .y(k_x_next));
    q12_mult mdt_y (.a(out_dy), .b(dt), .y(k_y_next));
    q12_mult mdt_z (.a(out_dz), .b(dt), .y(k_z_next));
    q12_mult mdt_w (.a(out_dw), .b(dt), .y(k_w_next));

    // Multiplier for final scaling (sum * 1/6)
    wire signed [23:0] final_x, final_y, final_z, final_w;
    q12_mult mfin_x (.a(sum_x), .b(INV_6), .y(final_x));
    q12_mult mfin_y (.a(sum_y), .b(INV_6), .y(final_y));
    q12_mult mfin_z (.a(sum_z), .b(INV_6), .y(final_z));
    q12_mult mfin_w (.a(sum_w), .b(INV_6), .y(final_w));

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            done <= 0;
            x_out <= 0; y_out <= 0; z_out <= 0; w_out <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    // Prep inputs for K1: f(x_in)
                    calc_x <= x_in; calc_y <= y_in; calc_z <= z_in; calc_w <= w_in;
                    sum_x <= 0; sum_y <= 0; sum_z <= 0; sum_w <= 0;
                    state <= S_K1;
                end

                S_K1: begin
                    // Capture K1
                    // Current sum = K1
                    sum_x <= k_x_next; sum_y <= k_y_next; sum_z <= k_z_next; sum_w <= k_w_next;
                    
                    // Prep inputs for K2: f(x + K1/2)
                    calc_x <= x_in + (k_x_next >>> 1);
                    calc_y <= y_in + (k_y_next >>> 1);
                    calc_z <= z_in + (k_z_next >>> 1);
                    calc_w <= w_in + (k_w_next >>> 1);
                    
                    state <= S_K2;
                end

                S_K2: begin
                    // Capture K2
                    // Current sum = K1 + 2*K2
                    sum_x <= sum_x + (k_x_next <<< 1);
                    sum_y <= sum_y + (k_y_next <<< 1);
                    sum_z <= sum_z + (k_z_next <<< 1);
                    sum_w <= sum_w + (k_w_next <<< 1);

                    // Prep inputs for K3: f(x + K2/2)
                    calc_x <= x_in + (k_x_next >>> 1);
                    calc_y <= y_in + (k_y_next <<< 1);
                    calc_z <= z_in + (k_z_next >>> 1);
                    calc_w <= w_in + (k_w_next >>> 1);

                    state <= S_K3;
                end

                S_K3: begin
                    // Capture K3
                    // Current sum = K1 + 2*K2 + 2*K3
                    sum_x <= sum_x + (k_x_next <<< 1);
                    sum_y <= sum_y + (k_y_next <<< 1);
                    sum_z <= sum_z + (k_z_next <<< 1);
                    sum_w <= sum_w + (k_w_next <<< 1);

                    // Prep inputs for K4: f(x + K3)  <-- Note: Full step, no divide by 2
                    calc_x <= x_in + k_x_next;
                    calc_y <= y_in + k_y_next;
                    calc_z <= z_in + k_z_next;
                    calc_w <= w_in + k_w_next;

                    state <= S_K4;
                end

                S_K4: begin
                    // Capture K4 and Final Sum
                    // Current sum = K1 + 2*K2 + 2*K3 + K4
                    // We can add K4 directly to the accumulator in the next logic
                    // Actually, we need to register the final sum to apply INV_6
                    // To save a cycle, we can just hold the values and move to IDLE
                    // but let's be safe and register outputs.
                    
                    // We use non-blocking updates, so final_x (which uses sum_x) 
                    // won't be ready until sum_x is updated. 
                    // Let's add K4 to sum here.
                    sum_x <= sum_x + k_x_next;
                    sum_y <= sum_y + k_y_next;
                    sum_z <= sum_z + k_z_next;
                    sum_w <= sum_w + k_w_next;
                    
                    // We need one more cycle to multiply by 1/6
                    // Let's re-use S_IDLE for the final update or add S_UPDATE
                    state <= 3'b101; // S_UPDATE
                end
                
                3'b101: begin // S_UPDATE
                    // x_out = x_in + sum * (1/6)
                    x_out <= x_in + final_x;
                    y_out <= y_in + final_y;
                    z_out <= z_in + final_z;
                    w_out <= w_in + final_w;
                    
                    done <= 1; // Pulse done signal
                    state <= S_IDLE; // Loop back immediately
                end
            endcase
        end
    end
endmodule