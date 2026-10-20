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

localparam HOLD_DELAY_CYCLES = 26'd50_000_000;   // 500 ms initial hold delay
    localparam INIT_INTERVAL     = 26'd20_000_000;   // 200 ms between pulses (5 Hz)
    localparam MIN_INTERVAL      = 26'd10000000;    // ~1ms
    localparam ACCEL_STEP        = 26'd1_200_000;    // Decrement interval per step

    reg [25:0] hold_timer;
    reg [25:0] repeat_timer;
    reg [25:0] current_interval;
    reg        repeat_pulse;

    always @(posedge CLK_100MHZ or negedge rst_n) begin
        if (!rst_n) begin
            hold_timer       <= 26'd0;
            repeat_timer     <= 26'd0;
            current_interval <= INIT_INTERVAL;
            repeat_pulse     <= 1'b0;
        end else if (!button2_deb) begin
            // Reset state when button is released
            hold_timer       <= 26'd0;
            repeat_timer     <= 26'd0;
            current_interval <= INIT_INTERVAL;
            repeat_pulse     <= 1'b0;
        end else begin
            repeat_pulse <= 1'b0;
            if (hold_timer < HOLD_DELAY_CYCLES) begin
                // Hold delay phase
                hold_timer <= hold_timer + 1'b1;
                repeat_timer <= 26'd0;
            end else begin
                // Repeating phase
                if (repeat_timer >= current_interval) begin
                    repeat_timer <= 26'd0;
                    repeat_pulse <= 1'b1; // Generate 1-cycle trigger

                    // Accelerate (decrease interval until MIN_INTERVAL)
                    if (current_interval > (MIN_INTERVAL + ACCEL_STEP))
                        current_interval <= current_interval - ACCEL_STEP;
                    else
                        current_interval <= MIN_INTERVAL;
                end else begin
                    repeat_timer <= repeat_timer + 1'b1;
                end
            end
        end
    end

    // Unified step pulse: single press OR held auto-repeat
    wire step_count = button2_pulse | repeat_pulse;

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

    reg [3:0] thousands_reg, hundreds_reg, tens_reg, units_reg;

    reg [3:0] thousands_next, hundreds_next, tens_next, units_next;



    reg [3:0] ring_counter_next, ring_counter_reg;

   always@(posedge CLK_100MHZ or negedge rst_n) begin
        if(!rst_n) begin
            ring_counter_reg <= 4'd0;
            dig_en_reg <= 4'd0;
            thousands_reg <= 4'd0;
            hundreds_reg <= 4'd0;
            tens_reg <= 4'd0;
            units_reg <=4'd0;
        end else begin
            ring_counter_reg <= ring_counter_next;
            dig_en_reg <= dig_en_next;
            thousands_reg <= thousands_next; 
            hundreds_reg <= hundreds_next;
            tens_reg <= tens_next;
            units_reg <= units_next;
        end
    end


    always@(*) begin
        ring_counter_next = ring_counter_reg;
        dig_en_next = dig_en_reg;
        thousands_next = thousands_reg;
        hundreds_next = hundreds_reg;
        tens_next = tens_reg;
        units_next = units_reg;

if (step_count) begin
    // Wrap around from 100 back to 0
    if (hundreds_reg == 4'd1 && tens_reg == 4'd0 && units_reg == 4'd0) begin
        hundreds_next  = 4'd0;
        tens_next      = 4'd0;
        units_next     = 4'd0;
        thousands_next = 4'd0;
    end else if (units_reg == 4'd9) begin
        units_next = 4'd0;
        if (tens_reg == 4'd9) begin
            tens_next     = 4'd0;
            hundreds_next = hundreds_reg + 1'b1; // Rolls 99 -> 100
        end else begin
            tens_next = tens_reg + 1'b1;
        end
    end else begin
        units_next = units_reg + 1'b1;
    end
end

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
        if(thousands_reg == 0) begin
            dig_en_next[0] = 1'b0;
            if(hundreds_reg == 0) begin
                dig_en_next[1] = 1'b0;
                if(tens_reg == 0) begin
                    dig_en_next[2] = 1'b0;
                end
            end
        end

    end

    assign display_digits = temp_display_signal_reg? ring_counter_reg : ((ring_counter_reg) & dig_en_reg);

    assign state = ~unit_state_reg;
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
            // Reset counter and start the 1.5-second display timer
            counter_display_next     = 32'd0;
            temp_display_signal_next = 1'b1;
        end else if (temp_display_signal_reg) begin
            if (counter_display_reg < 32'd150_000_000 - 1) begin
            counter_display_next = counter_display_reg + 1'b1;
            end else begin
                // 1.5 second has elapsed (150M cycles at 100 MHz)
                counter_display_next     = 32'd0;
                temp_display_signal_next = 1'b0;
            end
        end
    end
reg [3:0] digit;
    always@(*) begin
        digit = 4'd0;
        if( temp_display_signal_reg == 1'b1) begin
            segments = ~8'd0;

            case (unit_state_reg)
                `hertz: begin
                    if(display_digits[3]) 
                        segments = 8'b00100101;
                    if(display_digits[2])
                        segments = 8'b10010001;
                end

                `kilo: begin
                    if(display_digits[3]) 
                        segments = 8'b00100101;
                    if(display_digits[2])
                        segments = 8'b10010001;
                    if(display_digits[1])
                        segments = 8'b01010001;
                end

                `mega: begin
                    if(display_digits[3]) 
                        segments = 8'b00100101;
                    if(display_digits[2])
                        segments = 8'b10010001;
                    if(display_digits[1]) 
                        segments = 8'b00010011;
                    if(display_digits[0])
                        segments = 8'b10011111;
                    end
            endcase
       end
else begin
    
    case (ring_counter_reg)
        4'b0001: digit = thousands_reg;
        4'b0010: digit = hundreds_reg;
        4'b0100: digit = tens_reg;
        4'b1000: digit = units_reg;
        default: digit = 4'd0;
    endcase

    if (display_digits == 4'b0000) begin
        segments = ~8'd0;
    end else 
        case (digit)
            4'd0: segments = 8'b00000011;
            4'd1: segments = 8'b10011111;
            4'd2: segments = 8'b00100101;
            4'd3: segments = 8'b00001101;
            4'd4: segments = 8'b10011001;
            4'd5: segments = 8'b01001001;
            4'd6: segments = 8'b01000001;
            4'd7: segments = 8'b00011111;
            4'd8: segments = 8'b00000001;
            4'd9: segments = 8'b00001001;
            default: segments = ~8'd0;
        endcase
end
    end
// -------------------------------------------------------------------------
    // Stage 1: Trigger Detection & Registered BCD-to-Binary Conversion
    // -------------------------------------------------------------------------
    reg update_req;
    reg [6:0] val_reg;
    reg [25:0] num_reg;

    always @(posedge CLK_100MHZ or negedge rst_n) begin
        if (!rst_n) begin
            update_req <= 1'b0;
            val_reg    <= 7'd0;
            num_reg    <= 26'd50_000_000;
        end else begin
            // Trigger pipeline 1 cycle AFTER digits/units update
            update_req <= step_count | button1_pulse;

            // Register binary value V (0 to 100)
            val_reg <= (hundreds_reg == 4'd1) ? 7'd100 :
                       ((tens_reg << 3) + (tens_reg << 1) + units_reg);

            // Register numerator based on current unit state
            case (unit_state_reg)
                `hertz:  num_reg <= 26'd50_000_000;
                `kilo:   num_reg <= 26'd50_000;
                `mega:   num_reg <= 26'd50;
                default: num_reg <= 26'd50_000_000;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Stage 2: 26-Cycle Sequential Restoring Divider (1 bit per clock cycle)
    // -------------------------------------------------------------------------
    reg [4:0]  div_count;
    reg        div_busy;
    reg [25:0] dividend_shift;
    reg [25:0] quotient;
    reg [7:0]  remainder;
    reg [25:0] half_period_reg;

    wire [7:0] rem_shifted = {remainder[6:0], dividend_shift[25]};
    wire       sub_ge      = (rem_shifted >= {1'b0, val_reg});

    always @(posedge CLK_100MHZ or negedge rst_n) begin
        if (!rst_n) begin
            div_count       <= 5'd0;
            div_busy        <= 1'b0;
            dividend_shift  <= 26'd0;
            quotient        <= 26'd0;
            remainder       <= 8'd0;
            half_period_reg <= 26'd0;
        end else if (update_req) begin
            // Start new division when button press settles
            if (val_reg == 7'd0) begin
                half_period_reg <= 26'd0;
                div_busy        <= 1'b0;
            end else begin
                div_busy       <= 1'b1;
                div_count      <= 5'd25;
                dividend_shift <= num_reg;
                quotient       <= 26'd0;
                remainder      <= 8'd0;
            end
        end else if (div_busy) begin
            // Shift and subtract 1 bit per clock cycle
            dividend_shift <= {dividend_shift[24:0], 1'b0};
            if (sub_ge) begin
                remainder <= rem_shifted - {1'b0, val_reg};
                quotient  <= {quotient[24:0], 1'b1};
            end else begin
                remainder <= rem_shifted;
                quotient  <= {quotient[24:0], 1'b0};
            end

            if (div_count == 5'd0) begin
                div_busy <= 1'b0;
                // Commit final quotient to the active half-period register
                half_period_reg <= sub_ge ? {quotient[24:0], 1'b1} : {quotient[24:0], 1'b0};
            end else begin
                div_count <= div_count - 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Stage 3: Registered Square Wave Output Generator
    // -------------------------------------------------------------------------
    reg [25:0] wave_counter;
    reg        s_reg;

    always @(posedge CLK_100MHZ or negedge rst_n) begin
        if (!rst_n) begin
            wave_counter <= 26'd0;
            s_reg        <= 1'b0;
        end else if (half_period_reg == 26'd0) begin
            wave_counter <= 26'd0;
            s_reg        <= 1'b0;
        end else if (wave_counter >= half_period_reg - 1'b1) begin
            wave_counter <= 26'd0;
            s_reg        <= ~s_reg;
        end else begin
            wave_counter <= wave_counter + 1'b1;
        end
    end

    assign s = s_reg;

endmodule