`timescale 1ns / 1ps

module vga_controller(
    input clk,   
    input reset,        
    output video_on,    
    output hsync,      
    output vsync,     
    output p_pixel,     
    output [9:0] x,     
    output [9:0] y     
    );
    
    // Based on VGA standards found at vesa.org for 640x480 resolution
    // Total horizontal width of screen = 800 pixels, partitioned  into sections
    parameter h_display = 640;             // horizontal display area width 
    parameter h_front = 48;              // horizontal front porch width 
    parameter h_back = 16;              // horizontal back porch width 
    parameter h_retrace = 96;              // horizontal retrace width 
    parameter h_max = h_display + h_front + h_back + h_retrace - 1; // max value of horizontal counter = 799
    // Total vertical length of screen = 525 pixels, partitioned into sections
    parameter v_display = 480;             // vertical display area length 
    parameter v_front = 10;              // vertical front porch length  
    parameter v_back = 33;              // vertical back porch length  
    parameter v_retrace = 2;               // vertical retrace length   
    parameter v_max = v_display + v_front + v_back + v_retrace - 1; // max value of vertical counter = 524   
    
	reg  [1:0] r_25MHz;
	wire w_25MHz;
	
	always @(posedge clk or posedge reset)
		if(reset)
		  r_25MHz <= 0;
		else
		  r_25MHz <= r_25MHz + 1;
	
	assign w_25MHz = (r_25MHz == 0) ? 1 : 0; // assert tick 1/4 of the time
    
    // Counter Registers, two each for buffering to avoid glitches
    reg [9:0] h_count_reg, h_count_next;
    reg [9:0] v_count_reg, v_count_next;
    
    // Output Buffers
    reg v_sync_reg, h_sync_reg;
    wire v_sync_next, h_sync_next;
    
    // Register Control
    always @(posedge clk or posedge reset)
        if(reset) begin
            v_count_reg <= 0;
            h_count_reg <= 0;
            v_sync_reg  <= 1'b0;
            h_sync_reg  <= 1'b0;
        end
        else begin
            v_count_reg <= v_count_next;
            h_count_reg <= h_count_next;
            v_sync_reg  <= v_sync_next;
            h_sync_reg  <= h_sync_next;
        end
         
    //Logic for horizontal counter
    always @(posedge w_25MHz or posedge reset)      // pixel tick
        if(reset)
            h_count_next = 0;
        else
            if(h_count_reg == h_max)                 // end of horizontal scan
                h_count_next = 0;
            else
                h_count_next = h_count_reg + 1;         
  
    // Logic for vertical counter
    always @(posedge w_25MHz or posedge reset)
        if(reset)
            v_count_next = 0;
        else
            if(h_count_reg == h_max)                 // end of horizontal scan
                if((v_count_reg == v_max))           // end of vertical scan
                    v_count_next = 0;
                else
                    v_count_next = v_count_reg + 1;
        
    // h_sync_next asserted within the horizontal retrace area
    assign h_sync_next = (h_count_reg >= (h_display+h_back) && h_count_reg <= (h_display+h_back+h_retrace-1));
    
    // v_sync_next asserted within the vertical retrace area
    assign v_sync_next = (v_count_reg >= (v_display+v_back) && v_count_reg <= (v_display+v_back+v_retrace-1));
    
    // Video ON/OFF - only ON while pixel counts are within the display area
    assign video_on = (h_count_reg < h_display) && (v_count_reg < v_display); // 0-639 and 0-479 
            
    // Outputs
    assign hsync  = h_sync_reg;
    assign vsync  = v_sync_reg;
    assign x      = h_count_reg;
    assign y      = v_count_reg;
    assign p_pixel = w_25MHz;
            
endmodule
