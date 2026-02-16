`timescale 1ns / 1ps
module lorenz_decrypt_top(
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] ciphertext_in,
    output wire [63:0] plaintext_out,
    output wire        valid_out,
    // Debug Port
    output wire [63:0] keystream_monitor 
);

    // Q12.12 Registers
    reg signed [23:0] x_reg, y_reg, z_reg, w_reg;
    wire signed [23:0] x_next, y_next, z_next, w_next;
    wire step_done;

    // Constants (Q12.12)
    localparam signed [23:0] A_PARAM = 24'h00A000;
    localparam signed [23:0] B_PARAM = 24'h01C000;
    localparam signed [23:0] C_PARAM = 24'h002AAB;
    localparam signed [23:0] D_PARAM = 24'h001000;
    localparam signed [23:0] DT_PARAM = 24'h000029;
    localparam signed [23:0] INIT_VAL = 24'h001000;

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
        end else begin
            if (step_done) begin
                x_reg <= x_next; y_reg <= y_next; z_reg <= z_next; w_reg <= w_next;
            end
        end
    end

    // Assign Debug Port
    assign keystream_monitor = {w_reg[15:0], z_reg[15:0], y_reg[15:0], x_reg[15:0]};

    assign plaintext_out = ciphertext_in ^ {w_reg[15:0], z_reg[15:0], y_reg[15:0], x_reg[15:0]};
    assign valid_out = step_done;

endmodule