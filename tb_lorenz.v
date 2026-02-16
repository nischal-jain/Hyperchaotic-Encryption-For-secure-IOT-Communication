`timescale 1ns/1ps

module tb_lorenz;

  reg clk;
  reg rst;
  
  // Wires to connect to the Top Module
  wire [63:0] keystream;
  wire [63:0] ciphertext; // <--- Added Ciphertext Wire
  wire valid;

  // File handles
  integer f_key;
  integer f_cipher;

  // Instantiate top module with Ciphertext port
  lorenz_top uut (
    .clk(clk),
    .rst(rst),
    .keystream(keystream),
    .ciphertext(ciphertext), // <--- Connect the port
    .valid(valid)
  );

  // Clock generation (100MHz)
  initial clk = 0;
  always #5 clk = ~clk;

  // File management
  initial begin
    f_key = $fopen("rtl_keystream.txt", "w");
    f_cipher = $fopen("rtl_ciphertext.txt", "w"); // <--- New file for Ciphertext
    
    if (f_key == 0 || f_cipher == 0) begin
      $display("ERROR: Could not open file for writing!");
      $finish;
    end
  end

  // Monitor and Logging
  always @(posedge clk) begin
    if (valid) begin
        // --- 1. Console Output ---
        // Displays Time, Keystream (Hex), and Ciphertext (Hex)
        $display("Time=%0t | Keystream=%h | Ciphertext=%h", $time, keystream, ciphertext);
        
        // --- 2. File Output (Graph Data) ---
        // Writes binary/hex data to file for plotting/analysis
        $fwrite(f_key, "%064b\n", keystream); 
        $fwrite(f_cipher, "%h\n", ciphertext); 

        // Flush to ensure data is written immediately
        $fflush(f_key);
        $fflush(f_cipher);
    end
  end

  // Simulation Run Control
  initial begin
    // Reset Sequence
    rst = 1;
    #20;
    rst = 0;

    // Run for enough cycles to encrypt the message multiple times
    // 3 blocks * 6 cycles/block * 5 repeats = ~100 cycles
    repeat (200) @(posedge clk);  

    // Close files and finish
    $fclose(f_key);
    $fclose(f_cipher);
    $display("Simulation Finished. Data written to rtl_ciphertext.txt");
    $finish;
  end

endmodule