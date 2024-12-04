`timescale 1ns / 1ps

module pong(
    input clk,       // from Basys 3
    input reset,            // btnR
    input up,               // btnU
    input down,             // btnD
    output hsync,           // to VGA port
    output vsync,           // to VGA port
    output [11:0] rgb       // to DAC, to VGA port
    );
    
    wire w_reset, w_up, w_down, w_vid_on, w_p_tick;
    wire [9:0] w_x, w_y;
    reg [11:0] rgb_reg;
    wire [11:0] rgb_next;
    
    vga_controller vga(.clk(clk), .reset(w_reset), .video_on(w_vid_on),
                       .hsync(hsync), .vsync(vsync), .p_tick(w_p_tick), .x(w_x), .y(w_y));
    pixel pix(.clk(clk), .reset(w_reset), .up(w_up), .down(w_down), 
                 .video_on(w_vid_on), .x(w_x), .y(w_y), .rgb(rgb_next));
    debouncer dbright(.clk(clk), .button(reset), .clean(w_reset));
    debouncer dbup(.clk(clk), .button(up), .clean(w_up));
    debouncer dbdown(.clk(clk), .button(down), .clean(w_down));
    
    always @(posedge clk)
        if(w_p_tick)
            rgb_reg <= rgb_next;
            
    assign rgb = rgb_reg;
    
endmodule
