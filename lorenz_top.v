`timescale 1ns / 1ps
module lorenz_top(
    input  wire        clk,
    input  wire        rst,
    output wire [63:0] keystream,
    output reg  [63:0] ciphertext,
    output wire        valid
);

    reg signed [23:0] x_reg, y_reg, z_reg, w_reg;
    wire signed [23:0] x_next, y_next, z_next, w_next;
    wire step_done;

    // Q12.12 Constants
    localparam signed [23:0] A_PARAM = 24'h00A000;
    localparam signed [23:0] B_PARAM = 24'h01C000;
    localparam signed [23:0] C_PARAM = 24'h002AAB;
    localparam signed [23:0] D_PARAM = 24'h001000;
    localparam signed [23:0] DT_PARAM = 24'h000029;
    localparam signed [23:0] INIT_VAL = 24'h001000;

    reg [63:0] plaintext_rom [0:2];
    reg [1:0] text_idx; 

    initial begin
        plaintext_rom[0] = 64'h5468697320697320; 
        plaintext_rom[1] = 64'h456C656374726F6E;
        plaintext_rom[2] = 64'h20456C6974657300;
    end

    rk4_step rk4_inst (
        .clk(clk), .rst(rst),
        .x_in(x_reg), .y_in(y_reg), .z_in(z_reg), .w_in(w_reg),
        .a(A_PARAM), .b(B_PARAM), .c(C_PARAM), .d(D_PARAM), .dt(DT_PARAM),
        .x_out(x_next), .y_out(y_next), .z_out(z_next), .w_out(w_next),
        .done(step_done)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_reg <= INIT_VAL; y_reg <= INIT_VAL; z_reg <= INIT_VAL; w_reg <= INIT_VAL;
            text_idx <= 0;
            ciphertext <= 0;
        end else begin
            if (step_done) begin
                // Update State
                x_reg <= x_next; y_reg <= y_next; z_reg <= z_next; w_reg <= w_next;

                // --- THE FIX IS HERE ---
                // We use '_next' values to encrypt. This aligns the Cipher with the New State.
                ciphertext <= {w_next[15:0], z_next[15:0], y_next[15:0], x_next[15:0]} ^ plaintext_rom[text_idx];

                if (text_idx == 2) text_idx <= 0;
                else text_idx <= text_idx + 1;
            end
        end
    end

    assign keystream = {w_reg[15:0], z_reg[15:0], y_reg[15:0], x_reg[15:0]};
    assign valid = step_done;

endmodule