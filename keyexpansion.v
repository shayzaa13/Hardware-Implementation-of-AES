`timescale 1ns / 1ps

module keyexpansion (
    input clk,
    input rst,
    input valid,
    output reg done,
    output reg [127:0] key0, key1, key2, key3, key4, key5, key6, key7, key8, key9, key10, key11,
    output reg [14:0] block
);
    reg [3:0] k;
    reg [7:0] sbox_1;
    reg [7:0] sbox_2;
    reg [7:0] sbox_3;
    reg [7:0] sbox_4;
    wire [7:0] sbox_out1, sbox_out2, sbox_out3, sbox_out4;
    reg[31:0] temp;
    reg [31:0] sbox_temp;
    
    reg [127:0] prev_key;
    integer input_file, i, j, x, key_file;
    reg [7:0] image_data [0:262143];  
    reg [7:0] header_data;
    reg [127:0] round_keys [0:16383][0:10]; // 16384 sets of 11 round keys
    reg [127:0] initial_key;                //key[0] for each block
    reg [127:0] expanded_keys [0:10];       // Temporary storage for expanded keys
    reg [2:0] state;
    reg [127:0] inter_key;                  //intermediate key
    
    localparam IDLE=3'b000, READ_HEADER=3'b001, READ_PIXELS=3'b010,  PROCESS=3'b011, SBOX_INIT=3'b100, SBOX_WAIT=3'b101, DONE=3'b110;
    
    
    
    reg [31:0] rcon [0:10]; 
    initial begin
        rcon[0] = 32'h01000000;
        rcon[1] = 32'h02000000;
        rcon[2] = 32'h04000000;
        rcon[3] = 32'h08000000;
        rcon[4] = 32'h10000000;
        rcon[5] = 32'h20000000;
        rcon[6] = 32'h40000000;
        rcon[7] = 32'h80000000;
        rcon[8] = 32'h1b000000;
        rcon[9] = 32'h36000000;
        rcon[10]= 32'h6c000000;
    end
    
    sbox sbox1 (.data(sbox_1), .dout(sbox_out1));
    sbox sbox2 (.data(sbox_2), .dout(sbox_out2));
    sbox sbox3 (.data(sbox_3), .dout(sbox_out3));
    sbox sbox4 (.data(sbox_4), .dout(sbox_out4));
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            done <= 0;
            state <= IDLE;
            block<=0;
            i<=0;
            j<=0;
            k<=1;
            x<=0;
            header_data<=0;
            initial_key<=0;
            for (i = 0; i < 262144; i = i + 1) begin
                image_data[i] = 8'd0; 
            end
        end else begin
            case (state)
                IDLE: begin
                    if (valid) begin
                        input_file = $fopen("lena_gray.bmp", "rb");
                        if (input_file == 0) begin
                            $display("Error: Cannot open input image file");
                            $stop;
                        end
                        
                        key_file = $fopen("round_keys.txt", "wb");
                        if (key_file == 0) begin
                            $display("Error: Cannot open round_keys.txt file for writing");
                            $stop;
                        end

                        $display("KE: in idle state");
                        state <= READ_HEADER;
                    end
                    else
                        state<=IDLE;
                end
                
                READ_HEADER: begin  
                    for(i=0;i<1080;i=i+1) begin
                        $fscanf(input_file,"%c",header_data);
                    end
                    
                    $display("KE: in read header state");
                    state<=READ_PIXELS;
                end
                
                READ_PIXELS: begin
                    for(i = 0; i < 512*512; i = i + 1) begin
                            if ($fscanf(input_file, "%c", image_data[i]) != 1) begin
                                $display("ERROR: Failed to read pixel at index %0d", i);
                                $stop;
                            end                           
                   end
                   $display("KE: Pixel data read complete. Transitioning to PROCESS state...");
                   block<=0;
                   k=1;
                   state <= PROCESS;
                end
                
               PROCESS: begin
                        //$display("processing block %0d", block);
                        for (j = 0; j < 16; j = j + 1) begin
                            initial_key[(15 - j) * 8 +: 8] = image_data[ block* 16 + j];
                        end
                        
                        expanded_keys[0] = initial_key;
                        //$display("block %0d: initial key= %h", block, expanded_keys[0]);                       
                        k=1;
                        
                        state<= SBOX_INIT;
               end
                        
               SBOX_INIT: begin
                        prev_key= expanded_keys[k-1];
                        temp = prev_key[127: 96]; 
                        temp = {temp[23:0], temp[31:24]};  
                        sbox_1= temp[31:24];
                        sbox_2= temp[23:16];
                        sbox_3= temp[15:8];
                        sbox_4= temp[7:0];
                        state<=SBOX_WAIT;                          
               end
                
                SBOX_WAIT: begin                                     
                        sbox_temp= {sbox_out1, sbox_out2, sbox_out3, sbox_out4};                        
                        sbox_temp= sbox_temp^rcon[k-1];                            
                        inter_key= prev_key ^ {sbox_temp, prev_key[127:32]};
                        expanded_keys[k]= inter_key;
                        //$display("Block %0d: Key[%0d] = %h", block, k, inter_key);
                        k=k+1;
                            
                        if(k==12) begin
                            k=1;
                                                                                  
                            for(x=0; x<11; x=x+1) begin
                                round_keys[block][x]= expanded_keys[x];
                                $fwrite(key_file,"%h\n",round_keys[block][x]);                               
                            end 
                            key1=round_keys[block][0];
                            key2=round_keys[block][1];
                            key3=round_keys[block][2];
                            key4=round_keys[block][3];
                            key5=round_keys[block][4];
                            key6=round_keys[block][5];
                            key7=round_keys[block][6];
                            key8=round_keys[block][7];
                            key9=round_keys[block][8];
                            key10=round_keys[block][9];
                            key11=round_keys[block][10];
                            block=block+1;
                            
                            if(block==16384) begin
                                $display("KE: Processing done");
                                $fclose(key_file);                               
                                state<=DONE;
                            end
                            else state<=PROCESS;
                        end
                        
                        else state<= SBOX_INIT;                                                  
                  end
                                                               
                DONE: begin
                       //$display("in done state");                       
                       done = 1;
                       //$finish;
                end
            endcase
        end       
  end 
endmodule
