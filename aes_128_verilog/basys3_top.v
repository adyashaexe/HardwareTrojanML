// basys3_top.v
// Top-level wrapper to run aes_128 (or a Trojan variant) on the real
// Basys3 board. The Basys3 only has 16 switches, so the full 256-bit
// (plaintext + key) input can't be entered by hand -- this wrapper uses
// the FIPS-197 test vector as a FIXED input, triggered by a button, with
// the result visible on the LEDs one byte at a time (selected by switches).
//
// This is enough to prove on real hardware that "done" pulses correctly
// and the ciphertext matches the known-correct value byte by byte.
//
// TO TEST A TROJAN VARIANT: change the module name in the instantiation
// below (e.g. aes_128_trojan_leak instead of aes_128) and re-synthesize.
// Everything else in this wrapper stays the same.

module basys3_top (
    input  wire        clk_100mhz,   // W5 on Basys3 (onboard 100 MHz clock)
    input  wire        btnC,         // center button = start
    input  wire        btnU,         // up button = reset
    input  wire [15:0] sw,           // sw[3:0] selects which ciphertext byte to view
    output wire [15:0] led
);

    // ---- Fixed FIPS-197 test vector (hardcoded for hardware demo) ----
    localparam [127:0] KEY_FIXED       = 128'h000102030405060708090a0b0c0d0e0f;
    localparam [127:0] PLAINTEXT_FIXED = 128'h00112233445566778899aabbccddeeff;
    // Expected result: 69c4e0d86a7b0430d8cdb78070b4c55a  <- verify LEDs against this

    wire [127:0] ciphertext;
    wire         done;
    reg          start_pulse;
    reg          btnC_prev;

    // ---- Debounce-free single-cycle start pulse on button press ----
    always @(posedge clk_100mhz) begin
        btnC_prev   <= btnC;
        start_pulse <= btnC & ~btnC_prev; // rising edge only
    end

    // ---- Instantiate the design under test ----
    // Swap this module name to test a Trojan variant, e.g.:
    //   aes_128_trojan_leak dut ( ... same ports ... , .leak_out(leak_wire) );
    aes_128 dut (
        .clk(clk_100mhz),
        .rst(btnU),
        .start(start_pulse),
        .plaintext(PLAINTEXT_FIXED),
        .key(KEY_FIXED),
        .ciphertext(ciphertext),
        .done(done)
    );

    // ---- Byte selector: sw[3:0] picks which of the 16 ciphertext bytes
    //      to display on LEDs, so you can check the full 128-bit result
    //      by stepping through switch values 0-15 ----
    wire [7:0] selected_byte = ciphertext[127 - 8*sw[3:0] -: 8];

    assign led[7:0]  = selected_byte;
    assign led[14:8] = 7'd0;
    assign led[15]   = done;  // LED15 lights up when encryption is complete

endmodule
