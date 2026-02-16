`timescale 1ns / 1ps

module tb_decrypt_file;

    reg clk;
    reg rst;
    
    // Signals
    reg  [63:0] cipher_feed; 
    wire [63:0] plain_result;
    wire valid_out;
    
    // Debugging Signal
    wire [63:0] keystream_debug; // <--- NEW: To see the internal key

    // Temps
    reg [63:0] temp_trash; 
    integer f_in;
    integer scan_status;

    // --- Instantiate Receiver ---
    lorenz_decrypt_top uut (
        .clk(clk),
        .rst(rst),
        .ciphertext_in(cipher_feed),
        .plaintext_out(plain_result),
        .valid_out(valid_out),
        // We will tap into the internal keystream inside the module for debugging
        // Note: We need to modify the Top Module slightly to bring this out, 
        // OR we can reconstruct it here if we assume registers are exposed.
        // EASIER WAY: Let's add a port to lorenz_decrypt_top momentarily.
        .keystream_monitor(keystream_debug) // <--- You need to add this port below
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        f_in = $fopen("/home/ise/txt_format/rtl_ciphertext.txt", "r");
        
        if (f_in == 0) begin
            $display("ERROR: Could not open file.");
            $finish;
        end

        // --- SYNC FIX: Consume the zero line ---
        scan_status = $fscanf(f_in, "%h\n", temp_trash); 
        $display("Skipped initial garbage line: %h", temp_trash);

        rst = 1;
        cipher_feed = 0;
        #20;
        rst = 0;
        
        $display("--- Decryption Started ---");
    end

    always @(posedge clk) begin
        if (valid_out && !rst) begin
            if (!$feof(f_in)) begin
                scan_status = $fscanf(f_in, "%h\n", cipher_feed);
                
                if (scan_status == 1) begin
                    #1; 
                    // --- PRINTING KEYSTREAM NOW ---
                    $display("Time: %0t | Key: %h | Cipher: %h | DECRYPTED: %s", 
                             $time, keystream_debug, cipher_feed, plain_result);
                end
            end else begin
                $display("--- End of File Reached ---");
                $fclose(f_in);
                $finish;
            end
        end
    end

endmodule