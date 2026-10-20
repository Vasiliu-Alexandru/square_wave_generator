module square_wave_generator(
    input clk,
    input rst_n,
    input button1,
    input button2,
    output [1:0] state,
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
    
    /* local parameters */
    localparam [1:0] HZ  = 3'd0;
    localparam [1:0] kHz = 3'd1;
    localparam [1:0] MHz = 3'd2;
    
    reg button1_deb_d, button2_deb_d;

    wire button1_pulse = button1_deb & ~button1_deb_d;
    wire button2_pulse = button2_deb & ~button2_deb_d;


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
        counter_next <= counter_reg+1'b1;
        unit_state_next <= unit_state_reg;
        if (button1_pulse) begin
            if (unit_state_reg == MHz)
                unit_state_next <= HZ;
            else
                unit_state_next <= unit_state_reg + 2'd1;            
        end
    end


    assign state = ~unit_state_reg;
    assign s = ~counter_reg[27];


endmodule