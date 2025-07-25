`timescale 1ns / 1ps

module mixcolumns(
    input clk,
    input rst,
    input valid,
    output reg done
);
    integer input_file, output_file, i, j, r;
    reg [7:0] header_data;
    reg [7:0] pixel;
    reg [7:0] shifted_data [0:262143];
    reg [7:0] mixcol_data [0:262143];
    reg [7:0] state_matrix [0:15]; // 128-bit block (4x4 matrix)
    reg [7:0] temp_matrix [0:15];  // Temporary matrix for MixColumns output
    
    
    // AES MixColumns transformation multiplication
    function [7:0] xtime;
        input [7:0] in;
        begin
            xtime = (in << 1) ^ ((in[7]) ? 8'h1B : 8'h00);
        end
    endfunction
    
    task mix_columns;
        begin
            //integer r;
            for (r = 0; r < 4; r = r + 1) begin
                temp_matrix[r]     = xtime(state_matrix[r]) ^ (xtime(state_matrix[r+4]) ^ state_matrix[r+4]) ^ state_matrix[r+8] ^ state_matrix[r+12];
                temp_matrix[r+4]   = state_matrix[r] ^ xtime(state_matrix[r+4]) ^ (xtime(state_matrix[r+8]) ^ state_matrix[r+8]) ^ state_matrix[r+12];
                temp_matrix[r+8]   = state_matrix[r] ^ state_matrix[r+4] ^ xtime(state_matrix[r+8]) ^ (xtime(state_matrix[r+12]) ^ state_matrix[r+12]);
                temp_matrix[r+12]  = (xtime(state_matrix[r]) ^ state_matrix[r]) ^ state_matrix[r+4] ^ state_matrix[r+8] ^ xtime(state_matrix[r+12]);
            end
        end
    endtask
    
    reg [2:0] state;
    localparam IDLE= 3'b000, READ_HEADER= 3'b001, READ_PIXELS=3'b010, PROCESS_PIXELS=3'b011, WRITE_PIXELS=3'b100, DONE=3'b101;
    
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            pixel <= 0;
            header_data<=0;
            done<=0;
            i<=0;
            j<=0;
            for (i = 0; i < 262144; i = i + 1) begin
                shifted_data[i] = 8'd0; 
                mixcol_data[i] = 8'd0;                  
            end
        end 
        else begin
            case (state)
                IDLE: begin
                    if (valid) begin
                        input_file  = $fopen("shifted_lena.bmp", "rb");
                        output_file = $fopen("mixcol_lena.bmp", "wb");
                        
                        $fseek(input_file, 0, 0); 
    
                        if (input_file == 0 || output_file == 0) begin
                            $display("Could not open required file");
                            $stop;
                        end
                        $display("MIX: in idle state");
                        state <= READ_HEADER;
                    end
                    else
                        state<=IDLE;
                end
                
                READ_HEADER: begin  //working
                    for(i=0;i<1080;i=i+1) begin
                        $fscanf(input_file,"%c",header_data);
                        $fwrite(output_file,"%c",header_data);
                        //$display("Header Byte[%0d]: %h", i, header_data);
                    end
                    $display("MIX: in read header state");      
                    state<=READ_PIXELS;
                end
                
                READ_PIXELS: begin
                    for(i = 0; i < 512*512; i = i + 1) begin
                            if ($fscanf(input_file, "%c", shifted_data[i]) != 1) begin
                                $display("ERROR: Failed to read pixel at index %0d", i);
                                $stop;
                            end
                      /*      if (i % 65536 == 0) // Print progress every 65536 pixels
                                $display("Reading pixel %0d, value: %h", i, shifted_data[i]);*/
                    end
                    $display("MIX: Pixel data read complete. Transitioning to PROCESS_PIXELS...");
                    state <= PROCESS_PIXELS;
                end


                // 3. PROCESS_PIXEL: Apply S-Box transformation
                 PROCESS_PIXELS: begin
                    if (j < 512*512) begin
                        // Extract 16-byte block (128 bits)
                        for (i = 0; i < 16; i = i + 1) begin
                            state_matrix[i] = shifted_data[j + i];
                        end
                        
                        // Perform MixColumns
                        mix_columns();
                        
                        // Store transformed values
                        for (i = 0; i < 16; i = i + 1) begin
                            mixcol_data[j + i] = temp_matrix[i];
                        end
                        
                        j = j + 16; // Move to next 128-bit block
                    end else begin
                        $display("MIX: Processing done");
                        state <= WRITE_PIXELS;
                    end
                 end                 

                // 4. WRITE_PIXEL: Write transformed pixel to output file
                WRITE_PIXELS: begin               
                    for(j=0; j<512*512; j=j+1) begin
                        $fwrite(output_file, "%c", mixcol_data[j]);                        
                    end
                    $display("MIX: in write pixels state"); 
                    $fclose(output_file);                    
                    state<=DONE;                    
                end
                
               DONE: begin                                       
                    //$display("in done state");
                    done=1;                   
                    //$finish;
               end 
               
            endcase
        end
    end   
endmodule
  
