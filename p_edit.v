
`timescale 1ns / 1ps

module pixel(
    input clk,  
    input reset,    
    input up,
    input down,
    input video_on,
    input [9:0] x,
    input [9:0] y,
    output reg [11:0] rgb,
    output [:] collision_counter
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
    parameter paddle_velocity = 3;   
    parameter ball_size = 12; 
    wire [9:0] x_ball_l, x_ball_r;   // ball boundaries
    wire [9:0] y_ball_t, y_ball_b;
    reg [9:0] y_ball_reg, x_ball_reg; // position ball
    wire [9:0] y_ball_next, x_ball_next; //buffer
    reg [9:0] x_delta_reg, x_delta_next; //ball speed reg
    reg [9:0] y_delta_reg, y_delta_next;
    reg [9:0] ball_velocity_pos;  //ball velocity
    reg [9:0] ball_velocity_neg;
    wire [3:0] address, ball_col;   // 4-bit rom address and rom column
    reg [11:0] shape;             // data at current rom address (12-bit 12 columns)
    wire ball_bit;                   // shows when rom data is 1 or 0 for ball rgb control
    wire wall_on, paddle_on, ball_craft, ball_on;
    reg reset_ball; // responsible for setting the ball when game over
   
   reg [30:0] endgame_counter;
       // Add a delay counter for 5 seconds (assuming 100MHz clock)
    //reg [31:0] delay_counter;
    //parameter DELAY_CYCLES = 500_000_000; // 5 seconds delay (100 MHz clock)
    //reg delay_active;
    reg [10:0] collision_counter;

    ////////////////////////////LOGIC TO SET REGISTER PROPERTIES///////////////////////////////
    always @(posedge clk or posedge reset)begin
        if(reset) begin                            //If reset, set the positions, speeds and counters to zero
            y_paddle_reg = 0;
            x_ball_reg = 0;
            y_ball_reg = 0;
            x_delta_reg = 10'h002;
            y_delta_reg = 10'h002;
            endgame_counter = 0;
            collision_counter = 0;
            reset_ball = 0;
        end  
        else begin                                 //If not reset, set positions, speeds, and counter to next logic
            y_paddle_reg = y_paddle_next;
            x_ball_reg = x_ball_next;
            y_ball_reg = y_ball_next;
            x_delta_reg = x_delta_next;
            y_delta_reg = y_delta_next;
            reset_ball = 0;
        end
    end
    ///////////////////////////////////////////////////////////////////////////////////////////
               

        
        
        /*else begin
            if (collision_counter >= 5) 
            begin
        // Increase speed after 15 collisions
            ball_velocity_pos <= ball_velocity_pos + 20;// Increase speed
            ball_velocity_neg <= -(ball_velocity_pos); // Decrease negative velocity to match

            x_delta_reg <= x_delta_reg + 10'h002; // Increase speed by 1 (to simulate 0.5 increment)
            y_delta_reg <= y_delta_reg + 10'h002; // Increase speed by 1 (to simulate 0.5 increment)
            end 
   
        
            else begin
            endgame_counter <= 0;
                y_paddle_reg <= y_paddle_next;
                x_ball_reg <= x_ball_next;
                y_ball_reg <= y_ball_next;
                x_delta_reg <= x_delta_next;
                y_delta_reg <= y_delta_next;
            end
        end*/

    ///////////////////////////BALL PROPERTIES////////////////////////////////////////////////
    //Current Ball Properties
    assign x_ball_l = x_ball_reg;    
    assign y_ball_t = y_ball_reg;
    assign x_ball_r = x_ball_l + ball_size - 1;
    assign y_ball_b = y_ball_t + ball_size - 1;

    //Create the ball shape
    assign address = y[3:0] - y_ball_t[3:0];   // 4-bit address
    always @* begin
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
    end 

    //Pixel Location in Ball Box
    assign ball_col = x[3:0] - x_ball_l[3:0];    // 4-bit column index

    //Update the Next Ball Properties
    always @* begin
        x_delta_next = x_delta_reg;
        y_delta_next = y_delta_reg;

        if(x_paddle_R <= x_ball_r)                                  // collides with right screen
            reset_ball = 1;                                         // reset prop positions
            x_delta_next <= 10'h002;                                // reset ball velocity
            y_delta_next <= 10'h002;                                // reset ball velocity
            collision_counter = 0;                                  // reset collisions 
        else if(y_ball_t < 1)                                       // collide with top
            y_delta_next = ball_velocity_pos;                       // move down     
        else if(y_ball_b > y_MAX)                                   // collide with bottom
            y_delta_next = ball_velocity_neg;                       // move up         
        else if(x_ball_l <= x_wall_R)                               // collide with wall
            x_delta_next = ball_velocity_pos;                       // move right     
        else if((x_paddle_L <= x_ball_r) && (x_ball_r <= x_paddle_R) &&(y_paddle_t <= y_ball_b) && (y_ball_t <= y_paddle_b)) begin  // collide with paddle 
            x_delta_next = ball_velocity_neg;                       // move left
            collision_counter = collision_counter + 1;              // count the collision    
        end      
    end

    //Set Next Ball Properties
    assign x_ball_next = (refresh_tick) ? ((reset_ball) ? 0 : x_ball_reg + x_delta_reg) : x_ball_reg;
    assign y_ball_next = (refresh_tick) ? ((reset_ball) ? 0 : y_ball_reg + y_delta_reg) : y_ball_reg;
    ///////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////PADDLE PROPERTIES////////////////////////////////////////////
    //Current Paddle Properties
    assign y_paddle_t = y_paddle_reg;                             // paddle top position
    assign y_paddle_b = y_paddle_t + paddle_height - 1;           // paddle bottom position

    //Update and Set the Next Paddle Properties
    always @* begin
        y_paddle_next = y_paddle_reg;                            // no move
        if(refresh_tick)
            if(reset_ball)
                y_paddle_next = 0;                               // reset paddle
            else if(up & (y_paddle_t > paddle_velocity))
                y_paddle_next = y_paddle_reg - paddle_velocity;  // paddle up
            else if(down & (y_paddle_b < (y_MAX - paddle_velocity)))
                y_paddle_next = y_paddle_reg + paddle_velocity;  // paddle down
    end
    //////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////LOGIC TO DETERMINE CURRENT PIXEL PROP//////////////////////////
    //Wall Pixel?
    assign wall_on <= ((x_wall_L <= x) && (x <= x_wall_R)) ? 1 : 0;  

    //Paddle Pixel?
    assign paddle_on <= (x_paddle_L <= x) && (x <= x_paddle_R) && (y_paddle_t <= y) && (y <= y_paddle_b) ? 1 : 0;

    //Ball Pixel?
    assign ball_craft = (x_ball_l <= x) && (x <= x_ball_r) && (y_ball_t <= y) && (y <= y_ball_b); //Ball Boundaries
    assign ball_bit = shape[ball_col];                                                            //Ball Shape
    assign ball_on = ball_craft & ball_bit;                                                       //Ball Total
    //////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////LOGIC TO ASSIGN RGB COLOR///////////////////////////////////
    //Colors - in BGR order, not RGB
    wire [11:0] wall_rgb, pad_rgb, ball_rgb, bg_rgb;
    assign wall_rgb <= 12'h111;      // black wall
    assign pad_rgb <= 12'h111;       // black paddle
    assign ball_rgb <= 12'h1FF;      // yellow ball
    assign bg_rgb <= 12'hCCC;        // gray background

    always @* begin
        if(~video_on) begin
            rgb = 12'h000;          // no value
        end
        else begin
            if(wall_on)
                rgb = wall_rgb;     // wall color
            else if(paddle_on)
                rgb = pad_rgb;      // paddle color
            else if(ball_on)
                rgb = ball_rgb;     // ball color
            else
                rgb = bg_rgb;       // background
        end
    end
    ////////////////////////////////////////////////////////////////////////////////////////
                  
endmodule
