`timescale 1ns / 1ps

module debouncer(    
    output reg clean = 0,
    input button, clk
    );
    
 reg [2:0]count_val;

    wire max_val = &count_val;
    
    always @ (posedge clk)
        begin
            if (button == clean)
                count_val <= 0;
            else 
                count_val <= count_val + 4'd1;
                if (max_val) clean <= button;
        end    
endmodule
