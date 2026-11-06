// aes_128_trojan_hamming.v
// TROJAN VARIANT 6: Key-Correlated Toggle-Count Trojan
// -----------------------------------------------------------------------
// Trigger:  Sequential, latched. After TRIGGER_COUNT+1 completed
//           encryptions the Trojan becomes ACTIVE until reset.
// Payload:  Once active, on every encryption the Trojan toggles a bank
//           of flip-flops a number of times set by how many '1' bits are
//           in key[7:0] (its Hamming weight, 0-8). A key byte with more
//           1-bits produces more toggling, and so a slightly larger
//           power step, than a key byte with few 1-bits.
// Why it matters: this is the property that the published literature on
//           power-based key recovery (e.g. differential power analysis)
//           relies on -- that switching activity, and so power, can
//           depend on secret data. It gives this project a Trojan whose
//           signature is data-dependent rather than fixed, closer to
//           that literature than Variants 1-5.
// Stealth:  Ciphertext and done are unchanged; the key itself is never
//           driven onto any output pin, only the resulting toggle count.
// Scope note: this module demonstrates the DEPENDENCE of power on a
//           secret value for teaching and detection purposes. It does
//           not implement, and this project does not pursue, any scheme
//           for encoding or timing that dependence into a readable
//           message; a classifier only needs to tell this Trojan's power
//           shape apart from the clean baseline and the other variants.
// -----------------------------------------------------------------------

module aes_128_trojan_hamming #(
    parameter [7:0] TRIGGER_COUNT = 8'd31   // active after the 32nd encryption
) (
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire [127:0] plaintext,
    input  wire [127:0] key,
    output wire [127:0] ciphertext,
    output wire         done,
    output wire         tap
);

    aes_128 u_core (
        .clk(clk), .rst(rst), .start(start),
        .plaintext(plaintext), .key(key),
        .ciphertext(ciphertext), .done(done)
    );

    // ---- TROJAN TRIGGER ----
    reg [7:0] run_cnt;
    reg       active;
    reg       done_q;
    wire      done_rise = done & ~done_q;

    // ---- Hamming weight of key[7:0], computed once at start ----
    reg [3:0] weight;
    wire [3:0] weight_now =
        key[0] + key[1] + key[2] + key[3] +
        key[4] + key[5] + key[6] + key[7];

    // ---- TROJAN PAYLOAD: toggle a bank `weight` times per encryption ----
    reg  [3:0]  toggles_left;
    reg         busy;
    (* DONT_TOUCH = "true" *) reg [63:0] bank;

    always @(posedge clk) begin
        if (rst) begin
            run_cnt      <= 8'd0;
            active       <= 1'b0;
            done_q       <= 1'b0;
            weight       <= 4'd0;
            toggles_left <= 4'd0;
            busy         <= 1'b0;
            bank         <= 64'h5555555555555555;
        end else begin
            done_q <= done;

            if (start && !busy) begin
                weight <= weight_now;
                busy   <= 1'b1;
            end

            if (done_rise) begin
                busy <= 1'b0;
                if (!active) begin
                    if (run_cnt == TRIGGER_COUNT) active <= 1'b1;
                    else                          run_cnt <= run_cnt + 8'd1;
                end
                if (active) toggles_left <= weight; // one toggle per '1' bit
            end

            if (toggles_left != 4'd0) begin
                bank         <= {bank[62:0], ~bank[63]};
                toggles_left <= toggles_left - 4'd1;
            end
        end
    end

    assign tap = bank[0];

endmodule
