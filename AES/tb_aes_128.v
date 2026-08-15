// tb_aes_128.v
// Testbench validating aes_128 against the official FIPS-197 Appendix B
// known-answer test vector.

`timescale 1ns/1ps

module tb_aes_128;

    reg         clk;
    reg         rst;
    reg         start;
    reg  [127:0] plaintext;
    reg  [127:0] key;
    wire [127:0] ciphertext;
    wire         done;

    aes_128 dut (
        .clk(clk), .rst(rst), .start(start),
        .plaintext(plaintext), .key(key),
        .ciphertext(ciphertext), .done(done)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // FIPS-197 Appendix B test vector
    localparam [127:0] EXPECTED_CT = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

    initial begin
        clk   = 0;
        rst   = 1;
        start = 0;
        key       = 128'h000102030405060708090a0b0c0d0e0f;
        plaintext = 128'h00112233445566778899aabbccddeeff;

        repeat (2) @(posedge clk);
        rst = 0;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait (done == 1);
        @(posedge clk); // let ciphertext settle one extra cycle

        $display("Key        = %h", key);
        $display("Plaintext  = %h", plaintext);
        $display("Ciphertext = %h", ciphertext);
        $display("Expected   = %h", EXPECTED_CT);

        if (ciphertext === EXPECTED_CT)
            $display(">>> PASS: matches FIPS-197 test vector <<<");
        else
            $display(">>> FAIL: does NOT match expected output <<<");

        #20;
        $finish;
    end

    // Safety timeout
    initial begin
        #2000;
        $display("TIMEOUT: simulation did not finish");
        $finish;
    end

endmodule
