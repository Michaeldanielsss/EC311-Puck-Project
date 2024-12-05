`timescale 1ns / 1ps

module pong(
    input clk,       
    input reset,            // btnright
    input up,               // btnup
    input down,             // btndown
    output hsync,           // to VGA port
    output vsync,           // to VGA port
    output [11:0] rgb       // to DAC, to VGA port
    );
    
    wire w_reset, w_up, w_down, w_vid_on, w_pixel;
    wire [9:0] w_x, w_y;
    reg [11:0] reg_rgb;
    wire [11:0] w_rgb;
    
    vga_controller vga(.clk(clk), .reset(w_reset), .video_on(w_vid_on),
                       .hsync(hsync), .vsync(vsync), .p_pixel(w_pixel), .x(w_x), .y(w_y));
    pixel pix(.clk(clk), .reset(w_reset), .up(w_up), .down(w_down), 
              .video_on(w_vid_on), .x(w_x), .y(w_y), .rgb(w_rgb));
    debouncer dbright(.clk(clk), .button(reset), .clean(w_reset));
    debouncer dbup(.clk(clk), .button(up), .clean(w_up));
    debouncer dbdown(.clk(clk), .button(down), .clean(w_down));
    
    always @(posedge clk)
        if(w_pixel)
            reg_rgb <= w_rgb;
            
    assign rgb = reg_rgb;
    
endmodule
