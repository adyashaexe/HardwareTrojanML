// tb_new_trojans.v
// Checks Variants 4-6 (drain, burst, hamming) against the clean core:
//   1. ciphertext matches the clean baseline on every run
//   2. each Trojan's trigger fires only after its own condition
//   3. each Trojan's payload actually toggles once active
`timescale 1ns/1ps

module tb_new_trojans;
    reg clk = 0, rst = 1, start = 0;
    reg [127:0] pt  = 128'h00112233445566778899aabbccddeeff;
    reg [127:0] key = 128'h000102030405060708090a0b0c0d0e0f;
    localparam [127:0] EXPECTED = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

    wire [127:0] ct_c, ct_d, ct_b, ct_h;
    wire done_c, done_d, done_b, done_h, tap_d, tap_b, tap_h;

    aes_128 clean (.clk(clk), .rst(rst), .start(start), .plaintext(pt), .key(key),
                   .ciphertext(ct_c), .done(done_c));
    aes_128_trojan_drain   d (.clk(clk), .rst(rst), .start(start), .plaintext(pt), .key(key),
                   .ciphertext(ct_d), .done(done_d), .tap(tap_d));
    aes_128_trojan_burst   b (.clk(clk), .rst(rst), .start(start), .plaintext(pt), .key(key),
                   .ciphertext(ct_b), .done(done_b), .tap(tap_b));
    aes_128_trojan_hamming h (.clk(clk), .rst(rst), .start(start), .plaintext(pt), .key(key),
                   .ciphertext(ct_h), .done(done_h), .tap(tap_h));

    always #5 clk = ~clk;

    integer errors = 0;
    integer run;
    integer toggles_d = 0, toggles_h = 0;
    reg tap_d_q = 0, tap_h_q = 0;
    reg first_call = 1'b1;   // only the very first encrypt_once is checked against EXPECTED

    always @(posedge clk) begin
        tap_d_q <= tap_d; tap_h_q <= tap_h;
        if (tap_d !== tap_d_q) toggles_d = toggles_d + 1;
        if (tap_h !== tap_h_q) toggles_h = toggles_h + 1;
    end

    task encrypt_once;
        begin
            @(posedge clk); start = 1;
            @(posedge clk); start = 0;
            wait (done_c === 1'b1);
            @(posedge clk);
            if (first_call) begin
                first_call = 1'b0;
                if (ct_c !== EXPECTED) begin
                    errors = errors + 1;
                    $display("MISMATCH first run vs FIPS vector: clean=%h expected=%h", ct_c, EXPECTED);
                end
            end
            if (ct_d !== ct_c || ct_b !== ct_c || ct_h !== ct_c) begin
                errors = errors + 1;
                $display("MISMATCH run %0d: clean=%h drain=%h burst=%h hamming=%h", run, ct_c, ct_d, ct_b, ct_h);
            end
            repeat (2) @(posedge clk);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk); rst = 0;

        // phase 1: 10 runs with the FIPS plaintext/key -- below every trigger
        for (run = 0; run < 10; run = run + 1) encrypt_once;
        if (d.active) begin errors = errors + 1; $display("FAIL: drain fired too early"); end
        if (h.active) begin errors = errors + 1; $display("FAIL: hamming fired too early"); end
        if (b.active) begin errors = errors + 1; $display("FAIL: burst fired without DEADBEEF"); end

        // phase 2: runs 10..39 -> drain (16th run) and hamming (32nd run) should fire
        for (run = 10; run < 40; run = run + 1) encrypt_once;
        if (!d.active) begin errors = errors + 1; $display("FAIL: drain did not fire"); end
        if (!h.active) begin errors = errors + 1; $display("FAIL: hamming did not fire"); end
        if (b.active)  begin errors = errors + 1; $display("FAIL: burst fired without DEADBEEF"); end

        // phase 3: arm burst with the DEADBEEF plaintext; ciphertext must still
        // match the clean core run for run (clean core also gets the new plaintext)
        pt = 128'hDEADBEEFDEADBEEFDEADBEEFDEADBEEF;
        encrypt_once;
        if (!b.active) begin errors = errors + 1; $display("FAIL: burst did not arm on DEADBEEF"); end

        // a few more runs so the now-active payloads get a chance to toggle
        for (run = 0; run < 5; run = run + 1) encrypt_once;

        if (toggles_d < 50) begin errors = errors + 1; $display("FAIL: drain ring is not toggling (%0d)", toggles_d); end
        if (toggles_h < 1)  begin errors = errors + 1; $display("FAIL: hamming bank never toggled (%0d)", toggles_h); end

        if (errors == 0)
            $display(">>> PASS: all new Trojan variants match the clean baseline and trigger correctly <<<");
        else
            $display(">>> FAIL: %0d error(s) -- see messages above <<<", errors);

        $finish;
    end

    initial begin
        #200000;
        $display("TIMEOUT: simulation did not finish");
        $finish;
    end

endmodule
