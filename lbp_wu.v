module LBP (
    input  logic        clk,
    input  logic        reset,
    output logic [13:0] gray_addr,
    output logic        gray_req,
    input  logic        gray_ready,
    input  logic [7:0]  gray_data,
    output logic [13:0] lbp_addr,
    output logic        lbp_valid,
    output logic [7:0]  lbp_data,
    output logic        finish
);

    //================================================================
    // State Definition
    //================================================================
    typedef enum logic [2:0] {
        STATE_IDLE          = 3'd0,
        STATE_INPUT_MID     = 3'd1,
        STATE_INPUT_OUTSIDE = 3'd2,
        STATE_OUTPUT        = 3'd3,
        STATE_FINISH        = 3'd4
    } state_t;

    state_t cur_state, nx_state;

    //================================================================
    // Registers
    //================================================================
    logic [6:0] y, x;
    logic [6:0] y_out, x_out;
    logic [3:0] cnt_in;

    logic [7:0] lbp_sum;
    logic [7:0] gray_mid;

    //================================================================
    // Address Calculation
    //================================================================
    logic [13:0] addr_tmp [0:7];

    assign addr_tmp[7] = {y + 7'd1, x + 7'd1};
    assign addr_tmp[6] = {y + 7'd1, x};
    assign addr_tmp[5] = {y + 7'd1, x - 7'd1};
    assign addr_tmp[4] = {y,          x + 7'd1};
    assign addr_tmp[3] = {y,          x - 7'd1};
    assign addr_tmp[2] = {y - 7'd1, x + 7'd1};
    assign addr_tmp[1] = {y - 7'd1, x};
    assign addr_tmp[0] = {y - 7'd1, x - 7'd1};

    //================================================================
    // LBP Calculation
    //================================================================
    logic       idata_buf;
    logic [2:0] shift_flag;
    logic [7:0] lpb_mul;

    assign idata_buf = (gray_mid > gray_data) ? 1'b0 : 1'b1;
    assign shift_flag = cnt_in - 4'd1;
    assign lpb_mul = idata_buf << shift_flag;

    //================================================================
    // FSM - State Register
    //================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            cur_state <= STATE_IDLE;
        else
            cur_state <= nx_state;
    end

    //================================================================
    // FSM - Next State Logic
    //================================================================
    always_comb begin
        nx_state = STATE_IDLE;

        case (cur_state)
            STATE_IDLE:
                nx_state = gray_ready ? STATE_INPUT_MID : STATE_IDLE;

            STATE_INPUT_MID:
                nx_state = STATE_INPUT_OUTSIDE;

            STATE_INPUT_OUTSIDE:
                nx_state = (cnt_in == 4'd8) ? STATE_OUTPUT
                                             : STATE_INPUT_OUTSIDE;

            STATE_OUTPUT:
                nx_state = (y_out == 7'd126 && x_out == 7'd126)
                           ? STATE_FINISH
                           : STATE_INPUT_MID;

            STATE_FINISH:
                nx_state = STATE_FINISH;

            default:
                nx_state = STATE_IDLE;
        endcase
    end

    //================================================================
    // Read Center Pixel
    //================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            gray_mid <= 8'd0;
        else if (cur_state == STATE_INPUT_MID)
            gray_mid <= gray_data;
    end

    //================================================================
    // Input Counter
    //================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            cnt_in <= 4'd0;
        else if (nx_state == STATE_INPUT_OUTSIDE)
            cnt_in <= cnt_in + 4'd1;
        else
            cnt_in <= 4'd0;
    end

    //================================================================
    // LBP Sum
    //================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            lbp_sum <= 8'd0;
        else if (cur_state == STATE_INPUT_OUTSIDE) begin
            if (cnt_in == 4'd1)
                lbp_sum <= idata_buf;
            else if (cnt_in > 4'd1)
                lbp_sum <= lbp_sum + lpb_mul;
        end
    end

    //================================================================
    // Gray Memory Request
    //================================================================
    assign gray_req =
        (cur_state == STATE_INPUT_MID) ||
        (cur_state == STATE_INPUT_OUTSIDE);

    //================================================================
    // Gray Address
    //================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            gray_addr <= 14'd0;
        else if (nx_state == STATE_INPUT_MID)
            gray_addr <= {y, x};
        else if (nx_state == STATE_INPUT_OUTSIDE) begin
            if (cnt_in < 4'd8)
                gray_addr <= addr_tmp[cnt_in];
        end
    end

    //================================================================
    // Finish
    //================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            finish <= 1'b0;
        else
            finish <= (cur_state == STATE_FINISH);
    end

    //================================================================
    // LBP Valid
    //================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            lbp_valid <= 1'b0;
        else
            lbp_valid <= (cur_state == STATE_OUTPUT);
    end

    //================================================================
    // LBP Address
    //================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            lbp_addr <= 14'd0;
        else if (cur_state == STATE_OUTPUT)
            lbp_addr <= {y_out, x_out};
    end

    //================================================================
    // LBP Data
    //================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            lbp_data <= 8'd0;
        else if (cur_state == STATE_OUTPUT)
            lbp_data <= lbp_sum;
    end

    //================================================================
    // X / Y Counter
    //================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            x <= 7'd1;
            y <= 7'd1;
        end
        else if (nx_state == STATE_OUTPUT) begin
            if (x == 7'd126) begin
                x <= 7'd1;
                y <= y + 7'd1;
            end
            else begin
                x <= x + 7'd1;
            end
        end
    end

    //================================================================
    // Output X / Y
    //================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            x_out <= 7'd1;
            y_out <= 7'd1;
        end
        else begin
            x_out <= x;
            y_out <= y;
        end
    end

endmodule
