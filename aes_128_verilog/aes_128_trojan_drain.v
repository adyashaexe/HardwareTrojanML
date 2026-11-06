// aes_128_trojan_drain.v
// TROJAN VARIANT 4: Time-Triggered Power-Drain Trojan
// -----------------------------------------------------------------------
// Trigger:  Sequential. A hidden 8-bit counter counts completed
//           encryptions. After TRIGGER_COUNT+1 encryptions the Trojan
//           becomes ACTIVE and stays active until reset (latched).
// Payload:  A 512-bit ring of flip-flops, preloaded with an alternating
//           pattern, that rotates every clock once active. Every flop
//           toggles every cycle, so the circuit draws a clearly higher,
//           steady extra current -- a denial-of-service-style Trojan, as
//           in the Trust-Hub "always-on activity" benchmark family.
// Stealth:  Ciphertext and done are bit-identical to the clean core at
//           all times; the only symptom is higher power draw.
// Why it is here: the Leak, Counter and Tiny variants change only a
//           handful of cells, which an INA219 (0.1 mA steps, millisecond
//           sampling) may not resolve. This variant is sized so its
//           power step is clearly above the sensor's resolution, giving
//           the classifier a class it can reliably learn -- useful for
//           showing the detector works at all before tackling smaller
//           Trojans.
// -----------------------------------------------------------------------

module aes_128_trojan_drain #(
    parameter integer N             = 512,   // ring length (multiple of 8)
    parameter [7:0]   TRIGGER_COUNT = 8'd15   // active after the 16th encryption
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

    // ---- TROJAN TRIGGER: count completed encryptions ----
    reg [7:0] run_cnt;
    reg       active;
    reg       done_q;
    wire      done_rise = done & ~done_q;

    // ---- TROJAN PAYLOAD: toggling ring ----
    (* DONT_TOUCH = "true" *) reg [N-1:0] drain_sr;

    always @(posedge clk) begin
        if (rst) begin
            run_cnt  <= 8'd0;
            active   <= 1'b0;
            done_q   <= 1'b0;
            drain_sr <= {(N/8){8'hAA}};
        end else begin
            done_q <= done;
            if (done_rise && !active) begin
                if (run_cnt == TRIGGER_COUNT) active <= 1'b1;
                else                          run_cnt <= run_cnt + 8'd1;
            end
            if (active)
                drain_sr <= {drain_sr[N-2:0], drain_sr[N-1]};
        end
    end

    assign tap = drain_sr[0];

endmodule
