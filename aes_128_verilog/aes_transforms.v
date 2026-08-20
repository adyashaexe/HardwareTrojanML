// SubBytes, ShiftRows, MixColumns, AddRoundKey for AES-128.
// State convention (matches FIPS-197): 128-bit word split into 16 bytes,
// byte index idx = row + 4*col, with byte[0] = state_in[127:120] (MSB first).

module sub_bytes (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : sb
            aes_sbox u_sbox (
                .in_byte(state_in[127 - 8*i -: 8]),
                .out_byte(state_out[127 - 8*i -: 8])
            );
        end
    endgenerate
endmodule


module shift_rows (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);
    // Extract 16 bytes: byte[idx] where idx = row + 4*col
    wire [7:0] b [0:15];
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : extract
            assign b[i] = state_in[127 - 8*i -: 8];
        end
    endgenerate

    // Row r shifts left by r columns: new[r][c] = old[r][(c+r) mod 4]
    // new_idx = r + 4*c ; old_idx = r + 4*((c+r) mod 4)
    wire [7:0] o [0:15];

    // Row 0: no shift
    assign o[0]  = b[0];
    assign o[4]  = b[4];
    assign o[8]  = b[8];
    assign o[12] = b[12];

    // Row 1: shift left by 1
    assign o[1]  = b[5];
    assign o[5]  = b[9];
    assign o[9]  = b[13];
    assign o[13] = b[1];

    // Row 2: shift left by 2
    assign o[2]  = b[10];
    assign o[6]  = b[14];
    assign o[10] = b[2];
    assign o[14] = b[6];

    // Row 3: shift left by 3
    assign o[3]  = b[15];
    assign o[7]  = b[3];
    assign o[11] = b[7];
    assign o[15] = b[11];

    assign state_out = {o[0],o[1],o[2],o[3],o[4],o[5],o[6],o[7],
                         o[8],o[9],o[10],o[11],o[12],o[13],o[14],o[15]};
endmodule


module mix_columns (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);
    // xtime: multiply by 2 in GF(2^8) with AES reduction polynomial
    function [7:0] xtime;
        input [7:0] a;
        begin
            xtime = a[7] ? ((a << 1) ^ 8'h1b) : (a << 1);
        end
    endfunction

    function [7:0] gmul2;
        input [7:0] a;
        begin
            gmul2 = xtime(a);
        end
    endfunction

    function [7:0] gmul3;
        input [7:0] a;
        begin
            gmul3 = xtime(a) ^ a;
        end
    endfunction

    wire [7:0] b [0:15];
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : extract
            assign b[i] = state_in[127 - 8*i -: 8];
        end
    endgenerate

    wire [7:0] o [0:15];
    genvar c;
    generate
        for (c = 0; c < 4; c = c + 1) begin : col
            // Column c occupies bytes [4c .. 4c+3] = rows 0,1,2,3
            assign o[4*c+0] = gmul2(b[4*c+0]) ^ gmul3(b[4*c+1]) ^ b[4*c+2]      ^ b[4*c+3];
            assign o[4*c+1] = b[4*c+0]        ^ gmul2(b[4*c+1]) ^ gmul3(b[4*c+2]) ^ b[4*c+3];
            assign o[4*c+2] = b[4*c+0]        ^ b[4*c+1]        ^ gmul2(b[4*c+2]) ^ gmul3(b[4*c+3]);
            assign o[4*c+3] = gmul3(b[4*c+0]) ^ b[4*c+1]        ^ b[4*c+2]        ^ gmul2(b[4*c+3]);
        end
    endgenerate

    assign state_out = {o[0],o[1],o[2],o[3],o[4],o[5],o[6],o[7],
                         o[8],o[9],o[10],o[11],o[12],o[13],o[14],o[15]};
endmodule


module add_round_key (
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    output wire [127:0] state_out
);
    assign state_out = state_in ^ round_key;
endmodule
