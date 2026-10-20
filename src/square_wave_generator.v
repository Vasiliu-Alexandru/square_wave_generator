`define hertz 2'b00
`define kilo 2'b01
`define mega 2'b10



module square_wave_generator(
    input clk,
    input rst_n,
    input button1,
    input button2,
    output [1:0] state,
    output [3:0] display_digits,
    output reg [7:0] segments,
    output s
);
    wire CLK_100MHZ; 

    Gowin_rPLL pll_i(
        .clkout(CLK_100MHZ), //output clkout
        .clkin(clk) //input clkin
    );
     
    wire button1_deb;
    wire button2_deb;

    debouncer #( .CLK_FREQ(100_000_000), .DEBOUNCE_TIME_MS(10))
              debouncer_1
              (.clk(CLK_100MHZ), .rst_n(rst_n), .button_in(~button1), .button_out(button1_deb));
    
    debouncer #( .CLK_FREQ(100_000_000), .DEBOUNCE_TIME_MS(10))
              debouncer_2
              (.clk(CLK_100MHZ), .rst_n(rst_n), .button_in(~button2), .button_out(button2_deb));


    reg [31:0] counter_reg;
    reg [31:0] counter_next;
    reg [1:0] unit_state_reg;
    reg [1:0] unit_state_next;
    
    
    reg button1_deb_d, button2_deb_d;

    wire button1_pulse = button1_deb & ~button1_deb_d;
    wire button2_pulse = button2_deb & ~button2_deb_d;
    reg [3:0] dig_en_reg, dig_en_next;
    reg counter_15_d;
    wire counter_15_impulse;
    reg temp_display_signal_reg, temp_display_signal_next;

    always @(posedge CLK_100MHZ or negedge rst_n) begin
        if (!rst_n) begin
            counter_reg <= 32'd0;
            button1_deb_d <= 1'b0;
            button2_deb_d <= 1'b0;
            unit_state_reg <= 2'd0;
        end else begin
            counter_reg <= counter_next;
            button1_deb_d <= button1_deb;
            button2_deb_d <= button2_deb;
            unit_state_reg <= unit_state_next;
        end
    end

    always @(*) begin
        counter_next = counter_reg+1'b1;
        unit_state_next = unit_state_reg;
        if (button1_pulse) begin
            if (unit_state_reg == `mega)
                unit_state_next = `hertz;
            else
                unit_state_next = unit_state_reg + 2'd1;            
        end
    end
    
    always @(posedge CLK_100MHZ or negedge rst_n) begin
        if(!rst_n)
            counter_15_d <= 0;
        else
            counter_15_d <= counter_reg[15];
    end
    
    assign counter_15_impulse = counter_reg[15] & ~(counter_15_d);


   always@(posedge CLK_100MHZ or negedge rst_n) begin
        if(!rst_n) begin
            ring_counter_reg <= 4'd0;
            dig_en_reg <= 4'd0;
        end else begin
            ring_counter_reg <= ring_counter_next;
            dig_en_reg <= dig_en_next;
        end
    end

    wire [3:0] thousands, hundreds, tens, units;
    assign thousands = 4'd3;
    assign hundreds = 4'd3;
    assign tens = 4'd2;
    assign units = 4'd5;

    reg [3:0] ring_counter_next, ring_counter_reg;

    always@(*) begin
        ring_counter_next = ring_counter_reg;
        dig_en_next = dig_en_reg;

        if (counter_15_impulse) begin
            case(ring_counter_reg)
                4'b0000: ring_counter_next = 4'b0001;
                4'b0001: ring_counter_next = 4'b0010;
                4'b0010: ring_counter_next = 4'b0100;
                4'b0100: ring_counter_next = 4'b1000;
                4'b1000: ring_counter_next = 4'b0001;
                default: ring_counter_next = 4'b0001;
            endcase
        end

        dig_en_next[3] = 1'b1;
        dig_en_next[2:0] = 3'b111;
        if(thousands == 0) begin
            dig_en_next[0] = 1'b0;
            if(hundreds == 0) begin
                dig_en_next[1] = 1'b0;
                if(tens == 0) begin
                    dig_en_next[2] = 1'b0;
                end
            end
        end

    end

    assign display_digits = temp_display_signal_reg? ring_counter_reg : ((ring_counter_reg) & dig_en_reg);

    assign state = ~unit_state_reg;
    assign s = ~counter_reg[27];
    reg [31:0] counter_display_next, counter_display_reg;
    always@(posedge CLK_100MHZ or negedge rst_n) begin
        if(!rst_n) begin 
            temp_display_signal_reg <= 1'b0;
            counter_display_reg <= 32'd0;
        end else begin
            temp_display_signal_reg <= temp_display_signal_next;
            counter_display_reg <= counter_display_next;
        end
    end
    
    reg [31:0] counter_copy;

always @(*) begin
    counter_display_next     = counter_display_reg;
    temp_display_signal_next = temp_display_signal_reg;

    if (button1_pulse) begin
        // Reset counter and start the 1-second display timer
        counter_display_next     = 32'd0;
        temp_display_signal_next = 1'b1;
    end else if (temp_display_signal_reg) begin
        if (counter_display_reg < 32'd100_000_000 - 1) begin
            counter_display_next = counter_display_reg + 1'b1;
        end else begin
            // 1 second has elapsed (100M cycles at 100 MHz)
            counter_display_next     = 32'd0;
            temp_display_signal_next = 1'b0;
        end
    end
end

    always@(*) begin
        if( temp_display_signal_reg == 1'b1) begin
            segments = ~8'd0;

            case (unit_state_reg)
                `hertz: begin
                    if(display_digits[3]) 
                        segments = ~8'b11011010;
                    if(display_digits[2])
                        segments = 8'b10010001;
                end

                `kilo: begin
                    if(display_digits[3]) 
                        segments = ~8'b11011010;
                    if(display_digits[2])
                        segments = 8'b10010001;
                    if(display_digits[1])
                        segments = 8'b01010001;
                end

                `mega: begin
                    if(display_digits[3]) 
                        segments = ~8'b11011010;
                    if(display_digits[2])
                        segments = 8'b10010001;
                    if(display_digits[1])
                        segments = 8'b11010101;
                    end
            endcase
       end
         else begin
              segments = ~8'd0;
        end
    end


endmodule