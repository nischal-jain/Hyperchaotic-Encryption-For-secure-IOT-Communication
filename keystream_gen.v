// keystream_gen.v
// Extracts and formats the 64-bit keystream from the 4D chaotic state variables.

`include "config.vh"

module keystream_gen (
    input  wire                  clk,
    input  wire                  rst,
    input  wire [`DATA_WIDTH-1:0] x_in,
    input  wire [`DATA_WIDTH-1:0] y_in,
    input  wire [`DATA_WIDTH-1:0] z_in,
    input  wire [`DATA_WIDTH-1:0] w_in,
    input  wire                  state_valid_in, 
    
    output reg  [`KEY_WIDTH-1:0] keystream,
    output wire                  keystream_valid
);

// We extract the lower 16 bits (fractional part) of each 24-bit variable (16 * 4 = 64 bits)
localparam KEY_FRAC_BITS = 16; 

always @(posedge clk or posedge rst) begin
    if (rst) begin
        keystream <= {`KEY_WIDTH{1'b0}};
    end else if (state_valid_in) begin
        // Concatenate the lowest 16 bits of the fractional part of each variable.
        keystream <= {
            w_in[KEY_FRAC_BITS-1:0], 
            z_in[KEY_FRAC_BITS-1:0], 
            y_in[KEY_FRAC_BITS-1:0], 
            x_in[KEY_FRAC_BITS-1:0] 
        };
    end
end

assign keystream_valid = state_valid_in;

endmodule