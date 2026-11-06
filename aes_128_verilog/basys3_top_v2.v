// basys3_top_v2.v
// Basys 3 wrapper that can build ANY of the seven designs by changing one
// parameter in Vivado (Settings > General > Verilog Options, or just edit
// the default below and re-synthesize). basys3_top.v is left untouched,
// so your existing Leak-variant bitstream flow still works as before.
//
//   VARIANT 0 = clean baseline       VARIANT 4 = trojan_drain   (steady power drain)
//   VARIANT 1 = trojan_leak          VARIANT 5 = trojan_burst   (activity-coupled burst)
//   VARIANT 2 = trojan_counter       VARIANT 6 = trojan_hamming (key-correlated toggle count)
//   VARIANT 3 = trojan_tiny
//
// Switches:  SW[3:0]  selects which ciphertext byte is shown on LED[7:0]
//            SW[14]   1 = CONTINUOUS RUN: encryptions run back to back with
//                     no button presses, so the power trace has no idle
//                     gaps between them. Use this while logging.
//            SW[15]   0 = FIPS-197 plaintext, 1 = DEADBEEF-pattern plaintext
//                     (arms trojan_leak's and trojan_burst's triggers)
// Buttons:   BTNC = single start (ignored while SW[14]=1), BTNU = reset
// Pmod JA:   leak_out[7:0] -- trojan_leak drives the leaked byte here;
//            drain/burst/hamming drive their single `tap` bit on
//            leak_out[0] (bits [7:1] tied low); other variants tie it to 0.
// -----------------------------------------------------------------------

module basys3_top_v2 #(
    parameter integer VARIANT = 0
) (
    input  wire        clk_100mhz,
    input  wire        btnC,
    input  wire        btnU,
    input  wire [15:0] sw,
    output wire [15:0] led,
    output wire [7:0]  leak_out
);

    localparam [127:0] KEY_FIXED         = 128'h000102030405060708090a0b0c0d0e0f;
    localparam [127:0] PLAINTEXT_NORMAL  = 128'h00112233445566778899aabbccddeeff;
    localparam [127:0] PLAINTEXT_TRIGGER = 128'hDEADBEEFDEADBEEFDEADBEEFDEADBEEF;

    wire [127:0] plaintext_selected = sw[15] ? PLAINTEXT_TRIGGER : PLAINTEXT_NORMAL;

    wire [127:0] ciphertext;
    wire         done;
    reg          start_pulse;
    reg          btnC_prev;
    reg          running;

    // Start on a button edge, or automatically whenever idle in continuous mode.
    wire auto_req = sw[14] & ~running & ~start_pulse;

    always @(posedge clk_100mhz) begin
        btnC_prev   <= btnC;
        start_pulse <= (btnC & ~btnC_prev) | auto_req;
        if (btnU)             running <= 1'b0;
        else if (start_pulse) running <= 1'b1;
        else if (done)        running <= 1'b0;
    end

    wire       tap;
    wire [7:0] leak_byte;

    generate
        if (VARIANT == 0) begin : g_clean
            aes_128 dut (.clk(clk_100mhz), .rst(btnU), .start(start_pulse),
                .plaintext(plaintext_selected), .key(KEY_FIXED),
                .ciphertext(ciphertext), .done(done));
            assign tap = 1'b0;
            assign leak_byte = 8'd0;
        end else if (VARIANT == 1) begin : g_leak
            aes_128_trojan_leak dut (.clk(clk_100mhz), .rst(btnU), .start(start_pulse),
                .plaintext(plaintext_selected), .key(KEY_FIXED),
                .ciphertext(ciphertext), .done(done), .leak_out(leak_byte));
            assign tap = 1'b0;
        end else if (VARIANT == 2) begin : g_counter
            aes_128_trojan_counter dut (.clk(clk_100mhz), .rst(btnU), .start(start_pulse),
                .plaintext(plaintext_selected), .key(KEY_FIXED),
                .ciphertext(ciphertext), .done(done));
            assign tap = 1'b0;
            assign leak_byte = 8'd0;
        end else if (VARIANT == 3) begin : g_tiny
            aes_128_trojan_tiny dut (.clk(clk_100mhz), .rst(btnU), .start(start_pulse),
                .plaintext(plaintext_selected), .key(KEY_FIXED),
                .ciphertext(ciphertext), .done(done));
            assign tap = 1'b0;
            assign leak_byte = 8'd0;
        end else if (VARIANT == 4) begin : g_drain
            aes_128_trojan_drain dut (.clk(clk_100mhz), .rst(btnU), .start(start_pulse),
                .plaintext(plaintext_selected), .key(KEY_FIXED),
                .ciphertext(ciphertext), .done(done), .tap(tap));
            assign leak_byte = 8'd0;
        end else if (VARIANT == 5) begin : g_burst
            aes_128_trojan_burst dut (.clk(clk_100mhz), .rst(btnU), .start(start_pulse),
                .plaintext(plaintext_selected), .key(KEY_FIXED),
                .ciphertext(ciphertext), .done(done), .tap(tap));
            assign leak_byte = 8'd0;
        end else begin : g_hamming
            aes_128_trojan_hamming dut (.clk(clk_100mhz), .rst(btnU), .start(start_pulse),
                .plaintext(plaintext_selected), .key(KEY_FIXED),
                .ciphertext(ciphertext), .done(done), .tap(tap));
            assign leak_byte = 8'd0;
        end
    endgenerate

    assign leak_out = (VARIANT == 1) ? leak_byte : {7'd0, tap};

    // Byte selector: step SW[3:0] through 0-15 to read out the full
    // 128-bit ciphertext 8 bits at a time on LED[7:0].
    wire [7:0] selected_byte = ciphertext[127 - 8*sw[3:0] -: 8];

    assign led[7:0]  = selected_byte;
    assign led[14:8] = 7'd0;
    assign led[15]   = done;

endmodule
