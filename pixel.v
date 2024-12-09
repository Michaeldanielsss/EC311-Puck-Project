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
    output reg [15:0] score_keep
    );
    
    parameter X_MAX = 639;
    parameter Y_MAX = 479;
    wire frame_refresh;
    assign frame_refresh = ((y == 481) && (x == 0)) ? 1 : 0; 
    parameter WALL_LEFT = 77;    
    parameter WALL_RIGHT = 84; 
    parameter PADDLE_LEFT = 620;
    parameter PADDLE_RIGHT = 624;    
    wire [9:0] paddle_top, paddle_bottom;
    parameter PADDLE_HEIGHT = 98;  
    reg [9:0] paddle_pos_reg, paddle_pos_next;
    parameter PADDLE_SPEED = 2;   
    reg [7:0] speed_counter = 0;
    parameter BALL_DIMENSION = 12; // Ball size updated to 12x12
    wire [9:0] ball_left, ball_right;   // ball boundaries
    wire [9:0] ball_top, ball_bottom;
    reg [9:0] ball_pos_y_reg, ball_pos_x_reg; // position ball
    wire [9:0] ball_pos_y_next, ball_pos_x_next; //reg buffer
    reg signed [9:0] x_velocity_reg, x_velocity_next; // signed for proper negative arithmetic
    reg signed [9:0] y_velocity_reg, y_velocity_next; // signed as well
    parameter signed BALL_SPEED_POS = 2;  
    parameter signed BALL_SPEED_NEG = -2;
    wire [3:0] rom_address, ball_column;   // 4-bit rom address and rom column
    reg [11:0] rom_data;             // data at current rom address (12-bit for 12 columns)
    wire ball_pixel;                   // signify when rom data is 1 or 0 for ball rgb control
    
    always @(posedge clk or posedge reset)
        if(reset) begin
            paddle_pos_reg <= 0;
            ball_pos_x_reg <= 0;
            ball_pos_y_reg <= 0;
            x_velocity_reg <= 10'h002;
            y_velocity_reg <= 10'h002;
            speed_counter <= 0;  // Reset speed count
            score_keep <= 16'b0000000000000000;
        end
        else begin
            paddle_pos_reg <= paddle_pos_next;
            ball_pos_x_reg <= ball_pos_x_next;
            ball_pos_y_reg <= ball_pos_y_next;
            x_velocity_reg <= x_velocity_next;
            y_velocity_reg <= y_velocity_next;
        // Increase speed_counter upon paddle collision
        if ((PADDLE_LEFT <= ball_right) && (ball_right <= PADDLE_RIGHT) &&
            (paddle_top <= ball_bottom) && (ball_top <= paddle_bottom) && (x_velocity_reg > 0)) begin
            speed_counter <= speed_counter + 1;
            score_keep <= score_keep + 16'b0000000000000001;
        end
        if (ball_right >= X_MAX) begin
            // Collision with right wall
            speed_counter <= 0; // reset to the initial speed
            score_keep <= 16'b0000000000000000;
        end
    end
    
    // ball rom
    always @*
        case(rom_address)
            4'b0000 : rom_data = 12'b000111111000;  
            4'b0001 : rom_data = 12'b001111111100; 
            4'b0010 : rom_data = 12'b111111111111;
            4'b0011 : rom_data = 12'b111111111111;
            4'b0100 : rom_data = 12'b001111111100; 
            4'b0101 : rom_data = 12'b100011110001;
            4'b0110 : rom_data = 12'b110000000011;
            4'b0111 : rom_data = 12'b111111111111; 
            4'b1000 : rom_data = 12'b111111111111;
            4'b1001 : rom_data = 12'b001111111100;
            4'b1010 : rom_data = 12'b000111111000;
            default : rom_data = 12'b000000000000;
        endcase

    
    wire wall_active, paddle_active, square_ball_active, ball_active;
    wire [11:0] wall_color, paddle_color, ball_color, background_color;
    
    assign wall_active = ((WALL_LEFT <= x) && (x <= WALL_RIGHT)) ? 1 : 0;
    //colors - in BGR order, not RGB
    assign wall_color = 12'h111;      // black wall
    assign paddle_color = 12'h111;       // black paddle
    assign ball_color = 12'h1FF;      // orange? ball
    assign background_color = 12'hCCC;       // gray background
    
    // paddle 
    assign paddle_top = paddle_pos_reg;                             // paddle top position
    assign paddle_bottom = paddle_top + PADDLE_HEIGHT - 1;              // paddle bottom position
    assign paddle_active = (PADDLE_LEFT <= x) && (x <= PADDLE_RIGHT) &&     // pixel within paddle boundaries
                           (paddle_top <= y) && (y <= paddle_bottom);
                    
    always @* begin
        paddle_pos_next = paddle_pos_reg;     // no move
        if(frame_refresh)
            if(up & (paddle_top > PADDLE_SPEED))
                paddle_pos_next = paddle_pos_reg - PADDLE_SPEED;  // paddle up
            else if(down & (paddle_bottom < (Y_MAX - PADDLE_SPEED)))
                paddle_pos_next = paddle_pos_reg + PADDLE_SPEED;  // paddle down
    end
    
    assign ball_left = ball_pos_x_reg;
    assign ball_top = ball_pos_y_reg;
    assign ball_right = ball_left + BALL_DIMENSION - 1;
    assign ball_bottom = ball_top + BALL_DIMENSION - 1;
    
    // pixel within ball boundaries
    assign square_ball_active = (ball_left <= x) && (x <= ball_right) &&
                                (ball_top <= y) && (y <= ball_bottom);
    // map current pixel location to address
    assign rom_address = y[3:0] - ball_top[3:0];   // 4-bit address
    assign ball_column = x[3:0] - ball_left[3:0];    // 4-bit column index
    assign ball_pixel = rom_data[ball_column];         // 1-bit signal ball data by column
    // pixel within round ball
    assign ball_active = square_ball_active & ball_pixel;      
    // new ball position
    assign ball_pos_x_next = (frame_refresh) ? ball_pos_x_reg + x_velocity_reg : ball_pos_x_reg;
    assign ball_pos_y_next = (frame_refresh) ? ball_pos_y_reg + y_velocity_reg : ball_pos_y_reg;
    
    // change ball direction after collision
    always @* begin
        x_velocity_next = x_velocity_reg;
        y_velocity_next = y_velocity_reg;
        if(ball_top < 1) begin
            // collide with top boundary
            y_velocity_next = BALL_SPEED_POS; // move down
        end else if(ball_bottom > Y_MAX) begin
            // collide with bottom boundary
            y_velocity_next = BALL_SPEED_NEG; // move up
        end else if(ball_left <= WALL_RIGHT) begin
            // collide with left wall
            x_velocity_next = BALL_SPEED_POS; // move right
            x_velocity_next = x_velocity_next + speed_counter;
        end else if ((PADDLE_LEFT <= ball_right) && (ball_right <= PADDLE_RIGHT) &&
             (paddle_top <= ball_bottom) && (ball_top <= paddle_bottom)) begin
            // collide with paddle
            if (x_velocity_reg > 0) begin
                x_velocity_next = -(x_velocity_reg + speed_counter);

            end 
            // vertical speed unchanged
            y_velocity_next = y_velocity_reg;
        end
    end


    always @*
        if(~video_on)
            rgb = 12'h000;      // no value, blank
        else
            if(wall_active)
                rgb = wall_color;     // wall color
            else if(paddle_active)
                rgb = paddle_color;      // paddle color
            else if(ball_active)
                rgb = ball_color;     // ball color
            else
                rgb = background_color;       // background
                  
endmodule
