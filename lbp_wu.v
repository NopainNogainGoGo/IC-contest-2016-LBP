module LBP (
    input         clk,           
    input         reset,         
    input      [7:0] gray_data,  
    output reg [5:0] gray_addr,  
    output reg       gray_req,   
    output reg [5:0] lbp_addr,   
    output reg       lbp_write,  
    output reg [7:0] lbp_data,   //0 - 255
    output reg       finish      
);
reg [1:0] current_state, next_state;
parameter READ   = 2'd0; 
parameter CAL    = 2'd1; 
parameter WRITE  = 2'd2; 
parameter DONE   = 2'd3; 
integer i;
reg [3:0]cnt; // Counter to read 9 neighbors (0-8)

//cs
always @(posedge clk or posedge reset) begin
    if (reset)
        current_state <= READ;
    else
        current_state <= next_state;
end

//ns
always @(*) begin
    case (current_state)
        READ  : next_state = (cnt == 9) ? CAL : READ;
        CAL   : next_state = WRITE;
        WRITE : next_state = (y == 6 && x == 6) ? DONE : READ;
                // If we finished the last pixel (6,6), we are DONE
                // Go back to process next pixel
        DONE  : next_state = DONE;
        default: next_state = READ;
    endcase
end


// ==========================================
//  READ 
// ==========================================
reg[5:0] data[3:0];
reg[2:0] x; //0 - 7
reg[2:0] y; //0 - 7

// center_addr
wire [5:0] center_addr;
assign center_addr = {y, x};
always @(posedge clk or posedge reset) begin
    if(reset) begin
        x <= 3'd1;  y <= 3'd1; 
    end else if (current_state == WRITE) begin
        if (x == 6) begin
            if (y == 6) begin   // If y==6 and x==6, we stay there (logic handled in FSM)
                x <= x;
                y <= y;              
            end else begin
                x <= 3'd1;
                y <= y + 3'd1;
            end
        end else begin
            x <= x + 3'd1;
        end
    end
end


// (x-1, y-1), (x, y-1), (x+1, y-1) ...
reg [2:0] target_x, target_y;
always @(*) begin
    // Calculate relative coordinates based on cnt
    // This maps 0..8 to the 3x3 grid around (x,y)
    case(cnt)
        4'd0: begin target_x = x-1; target_y = y-1; end // Top-Left
        4'd1: begin target_x = x;   target_y = y-1; end // Top-Mid
        4'd2: begin target_x = x+1; target_y = y-1; end // Top-Right
        4'd3: begin target_x = x-1; target_y = y;   end // Mid-Left
        4'd4: begin target_x = x;   target_y = y;   end // Center
        4'd5: begin target_x = x+1; target_y = y;   end // Mid-Right
        4'd6: begin target_x = x-1; target_y = y+1; end // Bot-Left
        4'd7: begin target_x = x;   target_y = y+1; end // Bot-Mid
        4'd8: begin target_x = x+1; target_y = y+1; end // Bot-Right
        default: begin target_x=x; target_y=y; end
    endcase
end


always @(posedge clk or posedge reset) begin
    if(reset)begin
        gray_addr <= 1'b0;
    end else if (current_state == READ)begin
        // Since target_x and target_x are 3 bits, {target_y, target_x} is equivalent to target_y*8 + target_x
        gray_addr <=  {target_y, target_x};
    end 
end


always @(posedge clk or posedge reset) begin
    if(reset)begin
        cnt <= 1'b0;
    end else if (cnt < 9)begin
        cnt <= cnt + 1;
    end else begin
        cnt <= 0;
    end
end


always @(posedge clk or posedge reset) begin
    if(reset)begin
        gray_req <= 1'b0;
    end else if (current_state == READ)begin
        gray_req <= 1'b1;
    end else begin
        gray_req <= 0;
    end
end


always @(posedge clk or posedge reset) begin
    if(reset)begin
        for(i=0;i<8;i=i+1)begin
            data[i] <= 6'b0;
        end
    end else if (current_state == READ)begin
        data[cnt] <= gray_data;
    end 
end


// ==========================================
//  CALCULATION
// ==========================================
wire bits[3:0];
assign center_pixel = data[4]; // Index 4 is the center
    
assign bits[0] = (data[0] >= center_pixel); // Weight 1   (2^0)
assign bits[1] = (data[1] >= center_pixel); // Weight 2   (2^1)
assign bits[2] = (data[2] >= center_pixel); // Weight 4   (2^2)
assign bits[3] = (data[3] >= center_pixel); // Weight 8   (2^3)
// Skip index 4 (center)
assign bits[4] = (data[5] >= center_pixel); // Weight 16  (2^4)
assign bits[5] = (data[6] >= center_pixel); // Weight 32  (2^5)
assign bits[6] = (data[7] >= center_pixel); // Weight 64  (2^6)
assign bits[7] = (data[8] >= center_pixel); // Weight 128 (2^7)

// Sequential Logic to store the result
always @(posedge clk or posedge reset) begin
    if(reset) begin
        lbp_data <= 8'd0; 
    end else if (current_state == CAL) begin
        // Simply assign the bits. In binary, {bit7, ... bit0} IS the sum.
        // Example: If bits are 00110101, the value is naturally 53.
        lbp_data <= {bits[7],bits[6],bits[5],bits[4],bits[3],bits[2],bits[1],bits[0]};
    end 
end


// ==========================================
// WRITE RESULT
// ==========================================
always @(posedge clk or posedge reset) begin
    if(reset)begin
        lbp_write <= 1'b0; 
    end else if (current_state == WRITE)begin
        lbp_write <= 1'b1;
    end 
end


always @(posedge clk or posedge reset) begin
    if(reset)begin
        lbp_addr <= 1'b0; 
    end else if (current_state == WRITE)begin
        lbp_addr <= center_addr;
    end 
end


// ==========================================
// DONE
// ==========================================
always @(posedge clk or posedge reset) begin
    if(reset)begin
        finish <= 1'b0; 
    end else if (current_state == DONE)begin
        finish <= 1'b1;
    end 
end

endmodule






