`timescale 1ns / 1ps

module debouncer(    
    output reg clean = 0,
    input button, clk
    );
    
 reg [2:0]counter;

    wire MAX = &counter;
    
    always @ (posedge clk)
        begin
            if (button == clean)
                counter <= 0;
            else 
                counter <= counter + 4'd1;
                if (MAX) clean <= button;
        end    
endmodule
