// cipher_datapath.v
// Synchronizes plaintext with the chaotic keystream and performs XOR encryption.

`include "config.vh"

module cipher_datapath (
    input  wire                  clk,
    input  wire                  rst,
    
    // Keystream Interface (Input from keystream_gen)
    input  wire [`KEY_WIDTH-1:0] keystream_in,
    input  wire                  key_valid_in, // Signal that a new keystream is available
    
    // Plaintext/Data Interface (Input from UDP/IP stack)
    input  wire [`KEY_WIDTH-1:0] plaintext_in, 
    input  wire                  pt_valid_in,  
    
    // Ciphertext Output Interface (Output to UDP/IP stack)
    output wire [`KEY_WIDTH-1:0] ciphertext_out,
    output wire                  ct_valid_out
);

// Register to hold the keystream block used for the current plaintext block (Step 2)
reg [`KEY_WIDTH-1:0] stored_key_reg;

// Register to buffer the plaintext for use in the XOR (optional, but safer practice)
reg [`KEY_WIDTH-1:0] stored_pt_reg;

// Register to signal when the ciphertext is valid
reg                  ct_valid_reg;

// --- Sequential Logic (Synchronization and Storage) ---
always @(posedge clk or posedge rst) begin
    if (rst) begin
        stored_key_reg <= {`KEY_WIDTH{1'b0}};
        stored_pt_reg  <= {`KEY_WIDTH{1'b0}};
        ct_valid_reg   <= 1'b0;
    end 
    // Trigger condition: A new plaintext block has arrived from the UDP stack
    else if (pt_valid_in) begin 
        // 1. Store the CURRENT Keystream (ensuring a unique key is used for each block)
        stored_key_reg <= keystream_in;
        
        // 2. Store the plaintext block
        stored_pt_reg  <= plaintext_in;
        
        // 3. Mark the output as valid in the NEXT cycle, as XOR is combinatorial
        ct_valid_reg   <= 1'b1;
    end else begin
        // Reset the valid signal if no new plaintext arrived
        ct_valid_reg   <= 1'b0;
    end
end

// --- Combinatorial Logic (XOR Encryption - Step 3) ---
// Ciphertext = Plaintext XOR Keystream
assign ciphertext_out = stored_pt_reg ^ stored_key_reg;
assign ct_valid_out   = ct_valid_reg;

endmodule