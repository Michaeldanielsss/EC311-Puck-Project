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
    
    wire wire_reset, w_up, w_down, w_vid_on, wire_pixel;
    wire [9:0] wire_x, wire_y;
    reg [11:0] reg_rgb;
    wire [11:0] wire_rgb;
    wire [15:0] wire_score;
    
    vga_controller vga(.clk(clk), .reset(wire_reset), .video_on(w_vid_on), .hsync(hsync), .vsync(vsync), .p_pixel(wire_pixel), .x(wire_x), .y(wire_y));
    pixel pix(.clk(clk), .reset(wire_reset), .up(w_up), .down(w_down), .video_on(w_vid_on), .x(wire_x), .y(wire_y), .rgb(wire_rgb), .score_keep(wire_score));
    debouncer dbright(.clk(clk), .button(reset), .clean(wire_reset));
    debouncer dbup(.clk(clk), .button(up), .clean(w_up));
    debouncer dbdown(.clk(clk), .button(down), .clean(w_down));
    
    always @(posedge clk)
        if(wire_pixel)
            reg_rgb <= wire_rgb;
            
    assign rgb = reg_rgb;
    assign score = wire_score;
    
endmodule
