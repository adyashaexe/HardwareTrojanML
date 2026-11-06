// aes_128_trojan_burst.v
// TROJAN VARIANT 5: Data-Triggered, Activity-Coupled Burst Trojan
// -----------------------------------------------------------------------
// Trigger:  Data (combinational compare at start). If plaintext[31:0] ==
//           32'hDEADBEEF when an encryption starts, the Trojan latches
//           ACTIVE until reset. (The Basys 3 trigger plaintext, SW[15]=1,
//           already ends in DEADBEEF, so one switch flip arms it.)
// Payload:  Eight 32-bit free-running counters (256 flip-flops) that
//           increment ONLY while an encryption is in progress. The extra
//           power therefore rises and falls together with AES activity,
//           rather than sitting at a constant offset -- a different,
//           activity-correlated signature from Variant 4's steady drain.
// Stealth:  Ciphertext and done are unchanged.
// Capture note: bursts last about 12 clock cycles per encryption, so
//           they show up clearly only when encryptions run back to back.
//           Use the continuous-run switch (SW[14]=1) in basys3_top_v2.v
//           when logging this variant.
// -----------------------------------------------------------------------

module aes_128_trojan_burst (
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

    // ---- TROJAN TRIGGER: data match latched at start ----
    reg active;
    reg busy;                       // high while an encryption is running
    wire arm = start && (plaintext[31:0] == 32'hDEADBEEF);

    // ---- TROJAN PAYLOAD: 8 free-running 32-bit counters ----
    (* DONT_TOUCH = "true" *) reg [31:0] lane [0:7];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            active <= 1'b0;
            busy   <= 1'b0;
            for (i = 0; i < 8; i = i + 1)
                lane[i] <= 32'hA5A5A5A5 ^ (i * 32'h01010101);
        end else begin
            if (arm)        active <= 1'b1;
            if (start)      busy   <= 1'b1;
            else if (done)  busy   <= 1'b0;
            if (active && busy)
                for (i = 0; i < 8; i = i + 1)
                    lane[i] <= lane[i] + 32'd1;
        end
    end

    assign tap = lane[0][0] ^ lane[7][31];

endmodule
