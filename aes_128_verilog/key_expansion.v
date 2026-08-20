// AES-128 key expansion: generates 11 round keys (128 bits each) from the
// original 128-bit cipher key. Purely combinational.

module key_expansion (
    input  wire [127:0] key,
    output wire [127:0] round_key0,
    output wire [127:0] round_key1,
    output wire [127:0] round_key2,
    output wire [127:0] round_key3,
    output wire [127:0] round_key4,
    output wire [127:0] round_key5,
    output wire [127:0] round_key6,
    output wire [127:0] round_key7,
    output wire [127:0] round_key8,
    output wire [127:0] round_key9,
    output wire [127:0] round_key10
);

    // Round constants (Rcon) for rounds 1-10, only the top byte is non-zero
    wire [7:0] rcon [1:10];
    assign rcon[1]  = 8'h01;
    assign rcon[2]  = 8'h02;
    assign rcon[3]  = 8'h04;
    assign rcon[4]  = 8'h08;
    assign rcon[5]  = 8'h10;
    assign rcon[6]  = 8'h20;
    assign rcon[7]  = 8'h40;
    assign rcon[8]  = 8'h80;
    assign rcon[9]  = 8'h1b;
    assign rcon[10] = 8'h36;

    // w[i] holds each 32-bit word of the key schedule; w[0..3] = original key
    wire [31:0] w [0:43];

    assign w[0] = key[127:96];
    assign w[1] = key[95:64];
    assign w[2] = key[63:32];
    assign w[3] = key[31:0];

    genvar i;
    generate
        for (i = 4; i < 44; i = i + 1) begin : key_sched
            wire [31:0] temp;
            wire [31:0] rot_sub;

            if (i % 4 == 0) begin
                // RotWord: rotate left by 8 bits, then SubWord via 4 S-boxes,
                // then XOR with Rcon on the top byte
                wire [31:0] rotated = {w[i-1][23:0], w[i-1][31:24]};
                wire [7:0] sb0, sb1, sb2, sb3;

                aes_sbox s0 (.in_byte(rotated[31:24]), .out_byte(sb0));
                aes_sbox s1 (.in_byte(rotated[23:16]), .out_byte(sb1));
                aes_sbox s2 (.in_byte(rotated[15:8]),  .out_byte(sb2));
                aes_sbox s3 (.in_byte(rotated[7:0]),   .out_byte(sb3));

                assign rot_sub = {sb0 ^ rcon[i/4], sb1, sb2, sb3};
                assign temp = rot_sub;
            end else begin
                assign temp = w[i-1];
            end

            assign w[i] = w[i-4] ^ temp;
        end
    endgenerate

    assign round_key0  = {w[0],  w[1],  w[2],  w[3]};
    assign round_key1  = {w[4],  w[5],  w[6],  w[7]};
    assign round_key2  = {w[8],  w[9],  w[10], w[11]};
    assign round_key3  = {w[12], w[13], w[14], w[15]};
    assign round_key4  = {w[16], w[17], w[18], w[19]};
    assign round_key5  = {w[20], w[21], w[22], w[23]};
    assign round_key6  = {w[24], w[25], w[26], w[27]};
    assign round_key7  = {w[28], w[29], w[30], w[31]};
    assign round_key8  = {w[32], w[33], w[34], w[35]};
    assign round_key9  = {w[36], w[37], w[38], w[39]};
    assign round_key10 = {w[40], w[41], w[42], w[43]};

endmodule
