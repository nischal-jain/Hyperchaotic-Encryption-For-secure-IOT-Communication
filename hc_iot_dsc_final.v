// hc_iot_dsc_final.v
// FINAL TOP MODULE for the Hyperchaotic IoT Device Security Core (HC-IoT-DSC).

`include "config.vh"

module hc_iot_dsc_final (
    // Primary FPGA I/O (UCF required)
    input  wire                 clk_50mhz,        // P84
    input  wire                 rst_n,            // P11

    // Data Input (Event-Driven Trigger)
    input  wire [`KEY_WIDTH-1:0] plaintext_in,     // Actual data input
    input  wire                  pt_valid_in,      // P45 (Push Button/Trigger)

    // Communication Output
    output wire                  uart_tx_pin,      // P116

    // LED Indication Output
    output wire                  led_cipher_ready  // P33
);

// --- Internal Wires ---
wire [`DATA_WIDTH-1:0] x_state, y_state, z_state, w_state;
wire engine_valid;
wire [`KEY_WIDTH-1:0] continuous_keystream;
wire keystream_ready;
wire [`KEY_WIDTH-1:0] ciphertext_out;
wire ct_valid_out;
wire [7:0]             uart_tx_data_out; // Corrected width
wire                   uart_tx_start_in;
wire                   uart_tx_busy_out;

// --- LED Toggling Logic ---
reg r_led_status = 1'b0;

always @(posedge clk_50mhz or negedge rst_n) begin
    if (~rst_n) begin
        r_led_status <= 1'b0;
    end
    else if (ct_valid_out) begin
        r_led_status <= ~r_led_status;
    end
end
assign led_cipher_ready = r_led_status;

// ------------------------------------------------------------------
// A. CHAOTIC CORE (Key Generation)
// ------------------------------------------------------------------
lorenz_rk4_engine U_RK4_ENGINE (
    .clk(clk_50mhz),
    .rst(~rst_n),
    .x_out(x_state), .y_out(y_state), .z_out(z_state), .w_out(w_state),
    .state_valid(engine_valid)
);

keystream_gen U_KEY_GEN (
    .clk(clk_50mhz),
    .rst(~rst_n),
    .x_in(x_state), .y_in(y_state), .z_in(z_state), .w_in(w_state),
    .state_valid_in(engine_valid),

    .keystream(continuous_keystream),
    .keystream_valid(keystream_ready)
);

// ------------------------------------------------------------------
// B. CIPHER LOGIC (Encryption)
// ------------------------------------------------------------------
cipher_datapath U_CIPHER_PATH (
    .clk(clk_50mhz),
    .rst(~rst_n),
    .keystream_in(continuous_keystream),
    .key_valid_in(keystream_ready),
    .plaintext_in(plaintext_in),
    .pt_valid_in(pt_valid_in),  // TRIGGERED BY PHYSICAL INPUT

    .ciphertext_out(ciphertext_out),
    .ct_valid_out(ct_valid_out)
);

// ------------------------------------------------------------------
// C. COMMUNICATION
// ------------------------------------------------------------------

// 1. Cipher-to-UART Interface (Protocol Sequencing)
cipher_to_uart_if U_SEC_TX_IF (
    .clk(clk_50mhz),
    .rst(~rst_n),
    .ciphertext_in(ciphertext_out),
    .ct_valid_in(ct_valid_out),

    .tx_i_data(uart_tx_data_out),
    .tx_i_start(uart_tx_start_in),
    .tx_o_busy(uart_tx_busy_out)
);

// 2. PROVEN UART Transmitter (Serializer)
uart_tx #(.CLK_FREQ(`CLK_FREQ_HZ), .BAUD_RATE(`BAUD_RATE)) U_UART_TX (
    .clk(clk_50mhz),
    .rst(~rst_n),
    .i_data(uart_tx_data_out),
    .i_start(uart_tx_start_in),
    .o_serial_tx(uart_tx_pin),
    .o_busy(uart_tx_busy_out)
);

endmodule