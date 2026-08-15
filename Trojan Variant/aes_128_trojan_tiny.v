// aes_128_trojan_tiny.v
// TROJAN VARIANT 3: Minimal-Footprint Combinational Trojan
// -----------------------------------------------------------------------
// Trigger:  Combinational, single specific BYTE match -- watches only
//           the LOWEST 8 bits of the plaintext (not the full 128-bit
//           block like Variant 1). Fires whenever plaintext[7:0] == 8'h5A.
//           This is intentionally a much CHEAPER/simpler trigger than
//           Variant 1's full 128-bit comparator, while still rare enough
//           (1/256 chance) not to collide with typical test vectors.
// Payload:  Flips 1 bit of the ciphertext's final byte. Smallest possible
//           payload -- just an XOR gate.
// Purpose:  This is your "hardest to detect" variant. Extra hardware is
//           just a 4-bit comparator + 1 XOR gate -- only a few logic
//           cells, so its power signature is much fainter than Variants
//           1 and 2. Use this to show how detection accuracy drops as
//           Trojan size shrinks -- a genuinely useful result to report,
//           not a flaw in your project.
// -----------------------------------------------------------------------

module aes_128_trojan_tiny (
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire [127:0] plaintext,
    input  wire [127:0] key,
    output reg  [127:0] ciphertext,
    output reg          done
);

    // ---- TROJAN TRIGGER LOGIC (tiny: only 8 bits watched) ----
    wire trojan_trigger = (plaintext[7:0] == 8'h5A);

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
    reg         trigger_latched; // captured at start so payload uses stable value

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
            fsm_state       <= IDLE;
            state_reg       <= 128'd0;
            round_cnt       <= 4'd0;
            ciphertext      <= 128'd0;
            done            <= 1'b0;
            trigger_latched <= 1'b0;
        end else begin
            case (fsm_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state_reg       <= plaintext ^ rk0;
                        round_cnt       <= 4'd1;
                        fsm_state       <= RUN;
                        trigger_latched <= trojan_trigger;
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
                    // ---- TROJAN PAYLOAD: flip 1 bit only if triggered ----
                    ciphertext <= trigger_latched ? {state_reg[127:8], state_reg[7:1], ~state_reg[0]}
                                                   : state_reg;
                    done       <= 1'b1;
                    fsm_state  <= IDLE;
                end

                default: fsm_state <= IDLE;
            endcase
        end
    end

endmodule
