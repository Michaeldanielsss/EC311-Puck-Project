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
    output reg [15:0] score_keep
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
    parameter ball_velocity_pos = 3;  //ball velocity
    parameter ball_velocity_neg = -3;
    wire [3:0] address, ball_col;   // 4-bit rom address and rom column
    reg [11:0] shape;             // data at current rom address (12-bit 12 columns)
    wire ball_bit;                   // shows when rom data is 1 or 0 for ball rgb control
    
    wire wall_on, paddle_on, ball_craft, ball_on;
    wire [11:0] wall_rgb, pad_rgb, ball_rgb, bg_rgb;
    

    always @(posedge clk or posedge reset)
        if(reset) begin
            y_paddle_reg <= 0;
            x_ball_reg <= 0;
            y_ball_reg <= 0;
            x_delta_reg <= 10'h002;
            y_delta_reg <= 10'h002;
            speed_count <= 0;  // Reset speed count
            score_keep <= 16'b0000000000000000;
        end
        else begin
            y_paddle_reg <= y_paddle_next;
            x_ball_reg <= x_ball_next;
            y_ball_reg <= y_ball_next;
            x_delta_reg <= x_delta_next;
            y_delta_reg <= y_delta_next;
            // Increase speed_count upon paddle collision
            if ((X_PAD_L <= x_ball_r) && (x_ball_r <= X_PAD_R) &&
                (y_pad_t <= y_ball_b) && (y_ball_t <= y_pad_b) && (x_delta_reg > 0)) begin
                speed_count <= speed_count + 1;
                                score_keep <= score_keep + 16'b0000000000000001;
            end
            if (x_ball_r >= x_MAX) begin
                // Collision with right wall
                speed_count <= 0; // reset to the initial speed
                score_keep <= 16'b0000000000000000;
            end
        end
    
    always @*
        case(address)
            4'b0000 : shape = 12'b000111111000;  
            4'b0001 : shape = 12'b001111111100; 
            4'b0010 : shape = 12'b111111111111;
            4'b0011 : shape = 12'b111111111111;
            4'b0100 : shape = 12'b001111111100; 
            4'b0101 : shape = 12'b100011110001;
            4'b0110 : shape = 12'b110000000011;
            4'b0111 : shape = 12'b111111111111; 
            4'b1000 : shape = 12'b111111111111;
            4'b1001 : shape = 12'b001111111100;
            4'b1010 : shape = 12'b000111111000;
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
        if(y_ball_t < 1) begin
            // collide with top boundary
            y_delta_next = ball_velocity_pos; // move down
        end else if(y_ball_b > y_MAX) begin
            // collide with bottom boundary
            y_delta_next = BALL_VELOCITY_NEG; // move up
        end else if(x_ball_l <= x_wall_R) begin
            // collide with left wall
            x_delta_next = ball_velocity_pos; // move right
            x_delta_next = x_delta_next + speed_count;
        end else if((x_paddle_L <= x_ball_r) && (x_ball_r <= x_paddle_R) &&
                (y_paddle_t <= y_ball_b) && (y_ball_t <= y_paddle_b)) begin
            // collide with paddle
            if (x_delta_reg > 0) begin
                x_delta_next = -(x_delta_reg + speed_count);

            end 
            // vertical speed unchanged
            y_delta_next = y_delta_reg;
        end
        //x_delta_next = x_delta_next + speed_count;
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
    parameter ball_velocity_pos = 3;  //ball velocity
    parameter ball_velocity_neg = -3;
    wire [3:0] address, ball_col;   // 4-bit rom address and rom column
    reg [11:0] shape;             // data at current rom address (12-bit 12 columns)
    wire ball_bit;                   // shows when rom data is 1 or 0 for ball rgb control
    
    wire wall_on, paddle_on, ball_craft, ball_on;
    wire [11:0] wall_rgb, pad_rgb, ball_rgb, bg_rgb;
    

    always @(posedge clk or posedge reset)
        if(reset) begin
            y_paddle_reg <= 0;
            x_ball_reg <= 0;
            y_ball_reg <= 0;
            x_delta_reg <= 10'h002;
            y_delta_reg <= 10'h002;
            speed_count <= 0;  // Reset speed count
            score_keep <= 16'b0000000000000000;
        end
        else begin
            y_paddle_reg <= y_paddle_next;
            x_ball_reg <= x_ball_next;
            y_ball_reg <= y_ball_next;
            x_delta_reg <= x_delta_next;
            y_delta_reg <= y_delta_next;
            // Increase speed_count upon paddle collision
            if ((X_PAD_L <= x_ball_r) && (x_ball_r <= X_PAD_R) &&
                (y_pad_t <= y_ball_b) && (y_ball_t <= y_pad_b) && (x_delta_reg > 0)) begin
                speed_count <= speed_count + 1;
                                score_keep <= score_keep + 16'b0000000000000001;
            end
            if (x_ball_r >= x_MAX) begin
                // Collision with right wall
                speed_count <= 0; // reset to the initial speed
                score_keep <= 16'b0000000000000000;
            end
        end
    
    always @*
        case(address)
            4'b0000 : shape = 12'b000111111000;  
            4'b0001 : shape = 12'b001111111100; 
            4'b0010 : shape = 12'b111111111111;
            4'b0011 : shape = 12'b111111111111;
            4'b0100 : shape = 12'b001111111100; 
            4'b0101 : shape = 12'b100011110001;
            4'b0110 : shape = 12'b110000000011;
            4'b0111 : shape = 12'b111111111111; 
            4'b1000 : shape = 12'b111111111111;
            4'b1001 : shape = 12'b001111111100;
            4'b1010 : shape = 12'b000111111000;
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
        if(y_ball_t < 1) begin
            // collide with top boundary
            y_delta_next = ball_velocity_pos; // move down
        end else if(y_ball_b > y_MAX) begin
            // collide with bottom boundary
            y_delta_next = BALL_VELOCITY_NEG; // move up
        end else if(x_ball_l <= x_wall_R) begin
            // collide with left wall
            x_delta_next = ball_velocity_pos; // move right
            x_delta_next = x_delta_next + speed_count;
        end else if((x_paddle_L <= x_ball_r) && (x_ball_r <= x_paddle_R) &&
                (y_paddle_t <= y_ball_b) && (y_ball_t <= y_paddle_b)) begin
            // collide with paddle
            if (x_delta_reg > 0) begin
                x_delta_next = -(x_delta_reg + speed_count);

            end 
            // vertical speed unchanged
            y_delta_next = y_delta_reg;
        end
        //x_delta_next = x_delta_next + speed_count;
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
