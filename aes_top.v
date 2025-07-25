`timescale 1ns / 1ps

module aes_top (
    input clk,       
    input rst,       
    output reg done  
);

    localparam IDLE = 3'b000, KEY_EXP = 3'b001, SUB_BYTES = 3'b010,
               SHIFT_ROWS = 3'b011, MIX_COLUMNS = 3'b100, ADD_ROUND_KEY = 3'b101, NEXT_ROUND = 3'b110, DONE = 3'b111;

    reg [2:0] state; 
    reg [3:0] round_counter; // Round counter for 10 rounds
    reg valid_keyexp, valid_subbytes, valid_shiftrows, valid_mixcolumns, valid_addroundkey;
    wire done_keyexp, done_subbytes, done_shiftrows, done_mixcolumns, done_addroundkey;

    keyexpansion keyexp_inst (
        .clk(clk),
        .rst(rst),
        .valid(valid_keyexp),
        .done(done_keyexp)
    );

    subbytes subbytes_inst (
        .clk(clk),
        .rst(rst),
        .valid(valid_subbytes),
        .done(done_subbytes)
    );

    shiftrows shiftrows_inst (
        .clk(clk),
        .rst(rst),
        .valid(valid_shiftrows),
        .done(done_shiftrows)
    );

    mixcolumns mixcolumns_inst (
        .clk(clk),
        .rst(rst),
        .valid(valid_mixcolumns),
        .done(done_mixcolumns)
    );

    addroundkey addroundkey_inst (
        .clk(clk),
        .rst(rst),
        .round(round_counter), // Dynamically assign round_counter
        .valid(valid_addroundkey),
        .done(done_addroundkey)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            round_counter <= 0;
            valid_keyexp <= 0;
            valid_subbytes <= 0;
            valid_shiftrows <= 0;
            valid_mixcolumns <= 0;
            valid_addroundkey <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // Start with Key Expansion
                    valid_keyexp <= 1;
                    $display("AES_TOP: Starting KeyExpansion...");
                    state <= KEY_EXP;
                end

                KEY_EXP: begin
                    if (done_keyexp) begin
                        valid_keyexp <= 0; // Deassert valid for KeyExpansion
                        valid_subbytes <= 1; // Start SubBytes for the first round
                        round_counter <= 0; // Initialize round counter
                        $display("AES_TOP: KeyExpansion complete. Starting SubBytes for round %0d...", round_counter);
                        state <= SUB_BYTES;
                    end
                end

                SUB_BYTES: begin
                    if (done_subbytes) begin
                        valid_subbytes <= 0; // Deassert valid for SubBytes
                        valid_shiftrows <= 1; // Move to ShiftRows
                        $display("AES_TOP: SubBytes complete for round %0d. Starting ShiftRows...", round_counter);
                        state <= SHIFT_ROWS;
                    end
                end

                SHIFT_ROWS: begin
                    if (done_shiftrows) begin
                        valid_shiftrows <= 0; // Deassert valid for ShiftRows
                        valid_mixcolumns <= 1; // Move to MixColumns
                        $display("AES_TOP: ShiftRows complete for round %0d. Starting MixColumns...", round_counter);
                        state <= MIX_COLUMNS;
                    end
                end

                MIX_COLUMNS: begin
                    if (done_mixcolumns) begin
                        valid_mixcolumns <= 0; // Deassert valid for MixColumns
                        valid_addroundkey <= 1; // Move to AddRoundKey
                        $display("AES_TOP: MixColumns complete for round %0d. Starting AddRoundKey...", round_counter);
                        state <= ADD_ROUND_KEY;
                    end
                end

                ADD_ROUND_KEY: begin
                    if (done_addroundkey) begin
                        valid_addroundkey <= 0; // Deassert valid for AddRoundKey
                        if (round_counter < 9) begin
                            round_counter <= round_counter + 1; // Increment round counter
                            $display("AES_TOP: AddRoundKey complete for round %0d. Proceeding to next round...", round_counter);
                            valid_subbytes<=1;
                            state <= SUB_BYTES; // Loop back to SubBytes for the next round
                        end else begin
                            $display("AES_TOP: AddRoundKey complete for final round %0d. AES encryption finished.", round_counter);
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1; // Overall AES operation is complete
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

