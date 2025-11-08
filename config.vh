// config.vh - Global System Configuration Parameters

`ifndef CONFIG_V
`define CONFIG_V

// --- Fixed-Point Arithmetic (Optimized for Spartan-6 Q12.12) ---
`define DATA_WIDTH 24
`define FRAC_WIDTH 12
`define INT_WIDTH  (`DATA_WIDTH - `FRAC_WIDTH)

// --- Key Stream Extraction Parameters ---
`define KEY_WIDTH  64
`define KEY_BYTES  (`KEY_WIDTH / 8)

// --- UART Parameters (Tweakable Timing) ---
// Using 9600 Baud for maximum reliability during initial testing.
`define CLK_FREQ_HZ 50000000 
`define BAUD_RATE 9600 
`define BAUD_DIVISOR (`CLK_FREQ_HZ / `BAUD_RATE) // Approx 5208

`endif // CONFIG_V