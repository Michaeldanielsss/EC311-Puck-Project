`timescale 1ns / 1ps

module pixel(
    input clk,  
    input reset,    
    input up,
    input down,
    input video_on,
    input [9:0] x,
    input [9:0] y,
    output reg [11:0] rgb
    );
    
    parameter x_MAX = 639;
    parameter y_MAX = 479;
    wire refresh_tick;
    assign refresh_tick = ((y == 481) && (x == 0)) ? 1 : 0; 
    parameter x_wall_L = 77;    
    parameter x_wall_R = 84; 
    parameter x_paddle_L = 620;
    parameter x_paddle_R = 624;    
    wire [9:0] y_paddle_t, y_paddle_b;
    parameter paddle_height = 98;  
    reg [9:0] y_paddle_reg, y_paddle_next;
    parameter paddle_velocity = 2;   
    parameter ball_size = 12; 
    wire [9:0] x_ball_l, x_ball_r;   // ball boundaries
    wire [9:0] y_ball_t, y_ball_b;
    reg [9:0] y_ball_reg, x_ball_reg; // position ball
    wire [9:0] y_ball_next, x_ball_next; //buffer
    reg [9:0] x_delta_reg, x_delta_next; //ball speed reg
    reg [9:0] y_delta_reg, y_delta_next;
    parameter ball_velocity_pos = 1;  //ball velocity
    parameter ball_velocity_neg = -1;
    wire [3:0] address, ball_col;   // 4-bit rom address and rom column
    reg [11:0] shape;             // data at current rom address (12-bit 12 columns)
    wire ball_bit;                   // shows when rom data is 1 or 0 for ball rgb control
    wire wall_on, paddle_on, ball_craft, ball_on;
    wire [11:0] wall_rgb, pad_rgb, ball_rgb, bg_rgb;
    reg reset_ball;
    reg [2:0] collisions;
    always @(posedge clk or posedge reset)
        if(reset) 
        begin
            y_paddle_reg <= 0;
            x_ball_reg <= 0;
            y_ball_reg <= 0;
            x_delta_reg <= 10'h002;
            y_delta_reg <= 10'h002;
            collisions <= 0;
        end
        
        else if (reset_ball)
        begin
            // Reset the ball position to the top-left corner (0,0)
//            y_paddle_reg <= 0;
            y_ball_reg <= 0;  // Place the ball at top-left corner
            x_ball_reg <= 0;  // Place the ball at top-left corner
            x_delta_reg <= 10'h002;   // Reset ball speed
            y_delta_reg <= 10'h002;   // Reset ball speed
            collisions <= 0;
        end
            
        else 
        begin
            y_paddle_reg <= y_paddle_next;
            x_ball_reg <= x_ball_next;
            y_ball_reg <= y_ball_next;
            x_delta_reg <= x_delta_next;
            y_delta_reg <= y_delta_next;
        end
    
    always @*
        case(address)
            4'b0000 : shape = 12'b000000000001;  
            4'b0001 : shape = 12'b000000000011; 
            4'b0010 : shape = 12'b000000000111;
            4'b0011 : shape = 12'b000000011111;
            4'b0100 : shape = 12'b000011111111; 
            4'b0101 : shape = 12'b111111111111;
            4'b0110 : shape = 12'b000011111111;
            4'b0111 : shape = 12'b000000011111; 
            4'b1000 : shape = 12'b000000000111;
            4'b1001 : shape = 12'b000000000011;
            4'b1010 : shape = 12'b000000000001;
            default : shape = 12'b000000000000;
        endcase
    
    assign wall_on = ((x_wall_L <= x) && (x <= x_wall_R)) ? 1 : 0;
    //colors - in BGR order, not RGB
    assign wall_rgb = 12'h111;      // black wall
    assign pad_rgb = 12'h111;       // black paddle
    assign ball_rgb = 12'h1FF;      // yellow ball
    assign bg_rgb = 12'hCCC;       // gray background
    
    // paddle 
    assign y_paddle_t = y_paddle_reg;                             // paddle top position
    assign y_paddle_b = y_paddle_t + paddle_height - 1;              // paddle bottom position
    assign paddle_on = (x_paddle_L <= x) && (x <= x_paddle_R) &&     // pixel within paddle boundaries
        (y_paddle_t <= y) && (y <= y_paddle_b);
                    
    always @* begin
        y_paddle_next = y_paddle_reg;     // no move
        if(refresh_tick)
            if(up & (y_paddle_t > paddle_velocity))
                y_paddle_next = y_paddle_reg - paddle_velocity;  // paddle up
        else if(down & (y_paddle_b < (y_MAX - paddle_velocity)))
                y_paddle_next = y_paddle_reg + paddle_velocity;  // paddle down
    end
    
    assign x_ball_l = x_ball_reg;
    assign y_ball_t = y_ball_reg;
    assign x_ball_r = x_ball_l + ball_size - 1;
    assign y_ball_b = y_ball_t + ball_size - 1;
    
    /*
    assign x_ball_l = 100;
    assign y_ball_t = 100;
    assign x_ball_r = x_ball_l + ball_size - 1;
    assign y_ball_b = y_ball_t + ball_size - 1;
    */
    // pixel within ball boundaries
    assign ball_craft = (x_ball_l <= x) && (x <= x_ball_r) &&
                        (y_ball_t <= y) && (y <= y_ball_b);
    // map current pixel location to address
    assign address = y[3:0] - y_ball_t[3:0];   // 4-bit address
    assign ball_col = x[3:0] - x_ball_l[3:0];    // 4-bit column index
    assign ball_bit = shape[ball_col];         // 1-bit signal ball data by column
    // pixel within round ball
    assign ball_on = ball_craft & ball_bit;      
    // new ball position
    assign x_ball_next = (refresh_tick) ? x_ball_reg + x_delta_reg : x_ball_reg;
    assign y_ball_next = (refresh_tick) ? y_ball_reg + y_delta_reg : y_ball_reg;
    
    // change ball direction after collision
    always @* begin
        x_delta_next = x_delta_reg;
        y_delta_next = y_delta_reg;
        reset_ball = 0;
        if(y_ball_t < 1)                                            // collide with top
        begin
            y_delta_next = ball_velocity_pos;                       // move down
                // Gradually increase the speed
            //x_delta_next = (x_delta_next > 0) ? x_delta_next + 2 : x_delta_next - 2;
            //y_delta_next = (y_delta_next > 0) ? y_delta_next + 2 : y_delta_next - 2;
        end
        else if(y_ball_b > y_MAX)                                   // collide with bottom
            y_delta_next = ball_velocity_neg;                       // move up

        else if(x_ball_l <= x_wall_R)                               // collide with wall
            x_delta_next = ball_velocity_pos;                       // move right

        else if((x_paddle_L <= x_ball_r) && (x_ball_r <= x_paddle_R) && (y_paddle_t <= y_ball_b) && (y_ball_t <= y_paddle_b))     // collision with paddle
        begin 
            x_delta_next = ball_velocity_neg;                       // move left
            collisions = collisions + 1;
            x_delta_next = (x_delta_next > 0) ? x_delta_next + 1 : x_delta_next - 1;
            y_delta_next = (y_delta_next > 0) ? y_delta_next + 1 : y_delta_next - 1;            
            /*if(collisions >= 3) // if collisions are greater than or equal to 3, then increase the speed of the ball
            begin
                // Gradually increase the speed
                x_delta_next = (x_delta_next > 0) ? x_delta_next + 4 : x_delta_next - 4;
                y_delta_next = (y_delta_next > 0) ? y_delta_next + 4 : y_delta_next - 4;
            end*/
        end
        else if((x_ball_l >= x_paddle_R)&& (y_paddle_t >= y_ball_b) && (y_ball_t >= y_paddle_b)) //if user misses the paddle
            reset_ball = 1;
    end                    
    
    always @*
        if(~video_on)
            rgb = 12'h000;      // no value
        else
            if(wall_on)
                rgb = wall_rgb;     // wall color
    else if(paddle_on)
                rgb = pad_rgb;      // paddle color
            else if(ball_on)
                rgb = ball_rgb;     // ball color
            else
                rgb = bg_rgb;       // background
                  
endmodule
