`timescale 1ns / 1ps

module shiftrows (
    input clk,       // Clock signal
    input rst,
    input valid,        // Active-high reset
    output reg done
);
    
    integer input_file, output_file, i, j, block_start;
    reg [7:0] header_data;
    reg [7:0] pixel;
    reg [7:0] subbytes_data [0:262143];    
    wire [7:0] sbox_out;  
    reg [7:0] shifted_data [0:262143];

    localparam IDLE= 3'b000, READ_HEADER= 3'b001, READ_PIXELS=3'b010, PROCESS_PIXELS=3'b011, WRITE_PIXELS=3'b100, DONE=3'b101;
    reg [2:0] state;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            pixel <= 0;
            header_data<=0;
            done<=0;
            j<=0;
            block_start<=0;
            for (i = 0; i < 262144; i = i + 1) begin
                subbytes_data[i] = 8'd0; 
                shifted_data[i] = 8'd0;                  
            end
        end 
        else begin
            case (state)
                IDLE: begin
                    if (valid) begin
                        input_file  = $fopen("subbytes_lena.bmp", "rb");
                        output_file = $fopen("shifted_lena.bmp", "wb");
                        
                        $fseek(input_file, 0, 0);  // Move to the beginning of the file
    
                        if (input_file == 0 || output_file == 0) begin
                            $display("Could not open required file");
                            $stop;
                        end
                        $display("SHIFT: in idle state");
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
                    $display("SHIFT: in read header state");      
                    state<=READ_PIXELS;
                end
                
                READ_PIXELS: begin
                    for(i = 0; i < 512*512; i = i + 1) begin
                            if ($fscanf(input_file, "%c", subbytes_data[i]) != 1) begin
                                $display("ERROR: Failed to read pixel at index %0d", i);
                                $stop;
                            end
                            /*if (i % 65536 == 0) // Print progress every 65536 pixels
                                $display("Reading pixel %0d, value: %h", i, subbytes_data[i]);*/
                   end
                   $display("SHIFT: Pixel data read complete. Transitioning to PROCESS_PIXELS...");
                   state <= PROCESS_PIXELS;
                end


                // 3. PROCESS_PIXEL: Apply S-Box transformation
              PROCESS_PIXELS: begin
                    if (j < 512*512/16) begin
                        block_start<= j*16;
                        // Row 0 (No shift)
                        shifted_data[block_start + 0]  = subbytes_data[block_start + 0];
                        shifted_data[block_start + 4]  = subbytes_data[block_start + 4];
                        shifted_data[block_start + 8]  = subbytes_data[block_start + 8];
                        shifted_data[block_start + 12] = subbytes_data[block_start + 12];

                        // Row 1 (Shift left by 1 byte)
                        shifted_data[block_start + 1]  = subbytes_data[block_start + 5];
                        shifted_data[block_start + 5]  = subbytes_data[block_start + 9];
                        shifted_data[block_start + 9]  = subbytes_data[block_start + 13];
                        shifted_data[block_start + 13] = subbytes_data[block_start + 1];

                        // Row 2 (Shift left by 2 bytes)
                        shifted_data[block_start + 2]  = subbytes_data[block_start + 10];
                        shifted_data[block_start + 6]  = subbytes_data[block_start + 14];
                        shifted_data[block_start + 10] = subbytes_data[block_start + 2];
                        shifted_data[block_start + 14] = subbytes_data[block_start + 6];

                        // Row 3 (Shift left by 3 bytes)
                        shifted_data[block_start + 3]  = subbytes_data[block_start + 15];
                        shifted_data[block_start + 7]  = subbytes_data[block_start + 3];
                        shifted_data[block_start + 11] = subbytes_data[block_start + 7];
                        shifted_data[block_start + 15] = subbytes_data[block_start + 11];

                        j = j + 1; // Move to next pixel
                        
                        //$display("shifted data [%0d] = %h", j, shifted_data[j]);
                    end 
                                    
                    if(j==512*512/16) begin
                        $display("SHIFT: Processing done");
                        state<= WRITE_PIXELS;
                    end 
                 end                 

                // 4. WRITE_PIXEL: Write transformed pixel to output file
                WRITE_PIXELS: begin               
                    for(j=0; j<512*512; j=j+1) begin
                        $fwrite(output_file, "%c", shifted_data[j]);                        
                    end
                    $display("SHIFT: in write pixels state");
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




