`timescale 1ns / 1ps

module pong(
    input clk,       
    input reset,            
    input up,               
    input down,             
    output hsync,           
    output vsync,           
    output [11:0] rgb,
    output [15:0] score
    );
    
    wire w_reset, w_up, w_down, w_vid_on, w_pixel;
    wire [9:0] w_x, w_y;
    reg [11:0] reg_rgb;
    wire [11:0] w_rgb;
    wire [15:0] w_score;
    
    vga_controller vga(.clk(clk), .reset(w_reset), .video_on(w_vid_on), .hsync(hsync), .vsync(vsync), .p_pixel(w_pixel), .x(w_x), .y(w_y));
    pixel pix(.clk(clk), .reset(w_reset), .up(w_up), .down(w_down), .video_on(w_vid_on), .x(w_x), .y(w_y), .rgb(w_rgb), .score_keep(w_score));
    debouncer dbright(.clk(clk), .button(reset), .clean(w_reset));
    debouncer dbup(.clk(clk), .button(up), .clean(w_up));
    debouncer dbdown(.clk(clk), .button(down), .clean(w_down));
    
    always @(posedge clk)
        if(w_pixel)
            reg_rgb <= w_rgb;
            
    assign rgb = reg_rgb;
    assign score = w_score;
    
endmodule
