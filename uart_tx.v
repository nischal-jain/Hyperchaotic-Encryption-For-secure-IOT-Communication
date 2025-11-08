`timescale 1ns / 1ps

// =============================================================================
// uart_tx.v
// A standard, parameterized UART Transmitter module.
//
// Parameters:
//   - CLK_FREQ:  The frequency of the system clock in Hz (e.g., 50_000_000).
//   - BAUD_RATE: The desired communication speed in bits per second (e.g., 9600).
//
// Operation:
//   1. Waits in the IDLE state until the `i_start` signal is pulsed high.
//   2. When triggered, it latches the 8-bit `i_data` and asserts `o_busy`.
//   3. It then transmits a low start bit for one bit-period.
//   4. It transmits the 8 data bits, LSB first, each for one bit-period.
//   5. It transmits a high stop bit for one bit-period.
//   6. It returns to the IDLE state and de-asserts `o_busy`.
// =============================================================================

module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
) (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] i_data,
    input  wire       i_start,
    output wire       o_serial_tx,
    output wire       o_busy
);

    // Calculate how many clock cycles are needed for one bit-period.
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // FSM state registers and data registers
    reg [3:0]  state_reg;
    reg [15:0] clk_counter_reg; // Counter for timing each bit
    reg [7:0]  data_reg;        // Register to hold the byte being sent
    reg [3:0]  bit_index_reg;   // Index for the current data bit (0 to 7)
    reg        tx_reg;          // The physical output pin state

    // FSM State Definitions
    localparam STATE_IDLE      = 4'd0;
    localparam STATE_START_BIT = 4'd1;
    localparam STATE_DATA_BITS = 4'd2;
    localparam STATE_STOP_BIT  = 4'd3;

    // Combinational assignments for module outputs
    assign o_serial_tx = tx_reg;
    assign o_busy = (state_reg != STATE_IDLE);

    // Main Sequential Logic (FSM)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_reg       <= STATE_IDLE;
            clk_counter_reg <= 0;
            bit_index_reg   <= 0;
            tx_reg          <= 1'b1; // UART is high when idle
            data_reg        <= 0;
        end else begin
            case (state_reg)
                STATE_IDLE: begin
                    tx_reg <= 1'b1;
                    if (i_start) begin
                        data_reg        <= i_data;
                        clk_counter_reg <= 0;
                        bit_index_reg   <= 0;
                        state_reg       <= STATE_START_BIT;
                    end
                end

                STATE_START_BIT: begin
                    tx_reg <= 1'b0; // Start bit is low
                    if (clk_counter_reg < CLKS_PER_BIT - 1) begin
                        clk_counter_reg <= clk_counter_reg + 1;
                    end else begin
                        clk_counter_reg <= 0;
                        state_reg       <= STATE_DATA_BITS;
                    end
                end

                STATE_DATA_BITS: begin
                    tx_reg <= data_reg[bit_index_reg];
                    if (clk_counter_reg < CLKS_PER_BIT - 1) begin
                        clk_counter_reg <= clk_counter_reg + 1;
                    end else begin
                        clk_counter_reg <= 0;
                        if (bit_index_reg < 7) begin
                            bit_index_reg <= bit_index_reg + 1;
                        end else begin
                            bit_index_reg <= 0;
                            state_reg     <= STATE_STOP_BIT;
                        end
                    end
                end

                STATE_STOP_BIT: begin
                    tx_reg <= 1'b1; // Stop bit is high
                    if (clk_counter_reg < CLKS_PER_BIT - 1) begin
                        clk_counter_reg <= clk_counter_reg + 1;
                    end else begin
                        clk_counter_reg <= 0;
                        state_reg       <= STATE_IDLE;
                    end
                end

                default:
                    state_reg <= STATE_IDLE;
            endcase
        end
    end
endmodule