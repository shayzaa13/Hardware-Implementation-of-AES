`timescale 1ns / 1ps

module subbytes (
    input clk,            
    input rst,            
    input valid_in,       // input data is valid
    output reg ready_out, // ready to accept new data
    output reg valid_out, // output data is valid
    input ack_in,         // next module has accepted the data
    input [7:0] pixel_in, 
    output reg [7:0] pixel_out 
);

    reg [17:0] pixel_index; // Index to track the current pixel (18 bits for 262,144 pixels)
    reg [7:0] pixel_buffer [0:262143]; 
    reg [7:0] pixel;        
    reg [7:0] transformed_data; 
    wire [7:0] sbox_out;    
    reg [17:0] write_index; // Write pointer for the internal buffer
    reg [17:0] read_index;  // Read pointer for streaming output

    sbox uut (
        .data(pixel),
        .dout(sbox_out)
    );

    localparam IDLE = 3'b000, READ_PIXEL = 3'b001, PROCESS_PIXEL = 3'b010, WRITE_BUFFER = 3'b011, STREAM_OUT = 3'b100;
    reg [2:0] state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            pixel_index <= 0;
            write_index <= 0;
            read_index <= 0;
            pixel <= 0;
            transformed_data <= 0;
            valid_out <= 0;
            ready_out <= 1;
            pixel_out <= 0;
        end else begin
            case (state)
                // IDLE: Wait for valid input data
                IDLE: begin
                    if (valid_in) begin
                        ready_out <= 0; // Not ready to accept new data until processing starts
                        state <= READ_PIXEL;
                        $display("in idle state, valid input rcvd");
                    end
                end

                READ_PIXEL: begin
                    if (pixel_index < 262144) begin
                        pixel <= pixel_in; // Load incoming pixel data
                        state <= PROCESS_PIXEL;
                        $display("READ_PIXEL: Reading pixel %d: %h", pixel_index, pixel_in);
                    end 
                    else begin
                        $display("All pixels read.");
                        state <= STREAM_OUT; 
                    end
                end

                PROCESS_PIXEL: begin
                    transformed_data <= sbox_out;
                    //$display("PROCESS_PIXEL: Pixel %d: %h transformed to %h", pixel_index, pixel, sbox_out); 
                    state <= WRITE_BUFFER;
                end

                WRITE_BUFFER: begin
                    pixel_buffer[write_index] <= transformed_data;
                    //$display("in write pixel %d", pixel_index); 
                    write_index <= write_index + 1; 
                    pixel_index <= pixel_index + 1;
                    read_index<=0; 
                    state <= READ_PIXEL; 
                end

                //Output transformed data one pixel at a time
                STREAM_OUT: begin
                    if (read_index < 262144) begin
                        $display("in stream out for pixel %d",read_index);
                        pixel_out <= pixel_buffer[read_index]; // Output pixel from buffer
                        valid_out <= 1; // Indicate valid output
                        if (ack_in) begin
                            valid_out <= 0; // Clear valid_out after acknowledgment
                            read_index <= read_index + 1; // Increment read pointer
                        end
                    end else begin
                        // Reset for the next operation
                        ready_out <= 1; // Ready for new input
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule






