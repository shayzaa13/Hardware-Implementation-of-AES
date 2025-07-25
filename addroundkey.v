`timescale 1ns / 1ps

module addroundkey (
    input clk,
    input rst,
    input valid,
    input [3:0] round,              // Input to specify the current round (1-10)
    output reg done                 // Signal to indicate completion
);
    reg [7:0] encrypted_data [0:262143];
    reg [7:0] pixel_data [0:262143];  // Pixel data from mix_col.bmp
    reg [127:0] round_keys [0:16383][0:10]; // Round keys from round_keys.txt
    reg [127:0] block_data;           // Block of pixel data
    reg [127:0] round_key;            // Selected round key
    integer input_file, key_file, output_file;
    reg [7:0] header_data;
    integer i, block_idx, byte_idx, j;
    reg [2:0] state;
    
    localparam IDLE = 3'b000, READ_HEADER = 3'b001, READ_PIXELS = 3'b010,
               READ_KEYS = 3'b011, PROCESS = 3'b100, WRITE_OUTPUT = 3'b101, DONE = 3'b110;

    initial begin
        done = 0;
        state = IDLE;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            done <= 0;
            state <= IDLE;
            block_idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (valid) begin
                        input_file = $fopen("mixcol_lena.bmp", "rb");
                        if (input_file == 0) begin
                            $display("Error: Cannot open mixcol_lena.bmp");
                            $stop;
                        end

                        key_file = $fopen("round_keys.txt", "r");
                        if (key_file == 0) begin
                            $display("Error: Cannot open round_keys.txt");
                            $stop;
                        end

                        output_file = $fopen("addroundkey_lena.bmp", "wb");
                        if (output_file == 0) begin
                            $display("Error: Cannot create addroundkey_lena.bmp");
                            $stop;
                        end
                        $display("ADR: in idle state");
                        state <= READ_HEADER;
                    end
                end

                READ_HEADER: begin
                    for (i = 0; i < 1080; i = i + 1) begin
                        $fscanf(input_file, "%c", header_data);
                        $fwrite(output_file, "%c", header_data);
                    end
                    state <= READ_PIXELS;
                end

                READ_PIXELS: begin
                    for (i = 0; i < 512*512; i = i + 1) begin
                        if ($fscanf(input_file, "%c", pixel_data[i]) != 1) begin
                            $display("Error: Failed to read pixel at index %d", i);
                            $stop;
                        end
                    end
                    $display("ADR: in read header state");
                    state <= READ_KEYS;
                end

                READ_KEYS: begin
                    // Read all round keys from the file
                    for (block_idx = 0; block_idx < 16384; block_idx = block_idx + 1) begin
                        for (i = 0; i < 11; i = i + 1) begin
                            if ($fscanf(key_file, "%h", round_keys[block_idx][i]) != 1) begin
                                $display("Error: Failed to read round key %0d for block %0d", block_idx, i);
                                $stop;
                            end
                        end
                    end
                    $display("ADR: in read KEYS state");
                    block_idx<=0;
                    j<=0;
                    state <= PROCESS;
                    
                end

                PROCESS: begin
                    // Process each block
                    if(block_idx <16384) begin
                        //$display("ADR: processing block %0d", block_idx);
                        // Collect block pixel data
                        for (j = 0; j < 16; j = j + 1) begin
                            block_data[(15 - j) * 8 +: 8] = pixel_data[block_idx * 16 + j];
                        end

                        // Select the appropriate round key
                        round_key = round_keys[block_idx][round];

                        // XOR operation for AddRoundKey
                        block_data = block_data ^ round_key;

                        // Store the encrypted block data back
                        for (j = 0; j < 16; j = j + 1) begin
                            encrypted_data[block_idx * 16 + j] = block_data[(15 - j) * 8 +: 8];
                        end
                        block_idx = block_idx + 1;                     
                    end
                    
                    else begin
                        $display("ADR: All blocks processed. Transitioning to DONE state...");
                        state <= WRITE_OUTPUT;
                    end
                end

                WRITE_OUTPUT: begin
                    // Write encrypted pixel data to output file
                    for (i = 0; i < 512*512; i = i + 1) begin
                        $fwrite(output_file, "%c", encrypted_data[i]);
                    end
                    $display("AddRoundKey: Encryption complete for round %d", round);
                    $fclose(input_file);
                    $fclose(key_file);
                    $fclose(output_file);
                    state <= DONE;
                end

                DONE: begin
                    //$display("ADR: in done state");
                    done = 1;
                    //$finish;
                end
            endcase
        end
    end
endmodule

