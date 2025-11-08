// cipher_to_uart_if.v
// Sequentially feeds 10 bytes (Start, 8x Ciphertext, End) to the proven uart_tx module.

`include "config.vh"

module cipher_to_uart_if (
    input  wire                 clk,
    input  wire                 rst,

    // Input from the Cipher Core
    input  wire [`KEY_WIDTH-1:0] ciphertext_in,
    input  wire                  ct_valid_in,

    // Output/Handshake to your uart_tx.v
    output reg  [7:0]            tx_i_data,
    output reg                   tx_i_start,
    input  wire                  tx_o_busy
);

// --- Local Parameters ---
localparam START_FLAG = 8'hAA;
localparam END_FLAG   = 8'h55;

// FSM States
localparam S_IDLE       = 3'd0;
localparam S_TX_START   = 3'd1;
localparam S_TX_DATA    = 3'd2;
localparam S_TX_END     = 3'd3;

// --- Registers ---
reg [3:0] r_byte_index;
reg [2:0] r_state;
reg [`KEY_WIDTH-1:0] r_cipher_data;
reg [6:0] r_start_bit; // FIX: Declared at module level

// --- Main Control FSM ---
always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_state <= S_IDLE;
        r_byte_index <= 0;
        r_cipher_data <= 0;
        tx_i_start <= 1'b0;
        tx_i_data <= START_FLAG;
        r_start_bit <= 0;
    end else begin
        tx_i_start <= 1'b0;

        case (r_state)
            S_IDLE: begin
                r_byte_index <= 0;
                tx_i_data <= START_FLAG;

                if (ct_valid_in) begin
                    r_cipher_data <= ciphertext_in;
                    r_state <= S_TX_START;
                end
            end

            S_TX_START: begin
                tx_i_data <= START_FLAG;

                if (!tx_o_busy) begin
                    tx_i_start <= 1'b1;
                    r_byte_index <= 1;
                    r_state <= S_TX_DATA;
                end
            end

            S_TX_DATA: begin
                r_start_bit <= (`KEY_WIDTH - (r_byte_index * 8));
                tx_i_data <= r_cipher_data[r_start_bit +: 8];

                if (!tx_o_busy) begin
                    tx_i_start <= 1'b1;

                    if (r_byte_index < 8) begin
                        r_byte_index <= r_byte_index + 1;
                        r_state <= S_TX_DATA;
                    end
                    else begin
                        r_byte_index <= r_byte_index + 1;
                        r_state <= S_TX_END;
                    end
                end
            end

            S_TX_END: begin
                tx_i_data <= END_FLAG;

                if (!tx_o_busy) begin
                    tx_i_start <= 1'b1;
                    r_state <= S_IDLE;
                end
            end

            default: r_state <= S_IDLE;
        endcase
    end
end

endmodule