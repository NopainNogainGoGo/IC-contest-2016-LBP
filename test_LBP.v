`timescale 1ns/10ps
`define CYCLE      10        	  // Modify your clock period here
`define End_CYCLE  100000              // Modify cycle times once your design need more cycle times!

  
`define EXP        "./golden1.dat"     


module testfixture;

parameter N_EXP   = 63; // 8 x 8 pixel
parameter N_PAT   = N_EXP;

reg   [7:0]   exp_mem    [0:N_EXP-1];

reg [7:0] LBP_dbg;
reg [7:0] exp_dbg;
wire [7:0] lbp_data;
reg   clk = 0;
reg   reset = 0;
reg   result_compare = 0;

integer err = 0;
integer times = 0;
reg over = 0;
integer exp_num = 0;
wire [5:0] gray_addr;
wire [5:0] lbp_addr;
wire [7:0] gray_data;
reg gray_ready = 0;
integer i;

   LBP LBP( .clk(clk), .reset(reset), 
            .gray_addr(gray_addr), .gray_req(gray_req), .gray_data(gray_data), 
	    .lbp_addr(lbp_addr), .lbp_write(lbp_write), .lbp_data(lbp_data), 
	    .finish(finish));
			
   lbp_mem u_lbp_mem(.lbp_write(lbp_write), .lbp_data(lbp_data), .lbp_addr(lbp_addr));
   gray_mem u_gray_mem(.gray_addr(gray_addr), .gray_req(gray_req), .gray_data(gray_data), .clk(clk));

initial	$readmemh (`EXP, exp_mem);

always begin #(`CYCLE/2) clk = ~clk; end

initial begin
	$fsdbDumpfile("LBP.fsdb");
	$fsdbDumpMDA;
	$fsdbDumpvars;
end


initial begin // result compare
	$display("-----------------------------------------------------\n");
 	$display("START!!! Simulation Start .....\n");
 	$display("-----------------------------------------------------\n");
	reset = 1'b0; 
   	@(negedge clk)  reset = 1'b1; 
   	#(`CYCLE*2);    reset = 1'b0; 
	#(`CYCLE*3); 
	wait( finish === 1 ) ;
	@(negedge clk); 
	for (i=0; i <N_PAT ; i=i+1) begin
			//@(posedge clk);  // TRY IT ! no comment this line for debugging !!
				exp_dbg = exp_mem[i]; LBP_dbg = u_lbp_mem.LBP_M[i];
				if (exp_mem[i] === u_lbp_mem.LBP_M[i]) begin
					$display("pixel %d is CORRECT !! expected result is %d", i, exp_dbg); 
				end
				else begin
					$display("");
					$display("pixel %d is WRONG !! expected result is %d, but real result is %d", i, exp_dbg, LBP_dbg); 
					$display("");
					err = err+1;
				end				
	end
	$display("-----------------------------------------------------\n");
         if (err == 0)  begin
            $display("Congratulations! All data have been generated successfully!\n");
            $display("-------------------------PASS------------------------\n");
         end
         else begin
            $display("There are %d errors!\n", err);
            $display("-----------------------------------------------------\n");
	    
         end
      #(`CYCLE/2); $finish;
end


initial  begin
 #`End_CYCLE ;
 	$display("-----------------------------------------------------\n");
 	$display("Error!!! Somethings' wrong with your code ...!\n");
 	$display("-------------------------FAIL------------------------\n");
 	$display("-----------------------------------------------------\n");
 	$finish;
end
   
endmodule


module lbp_mem (lbp_write, lbp_data, lbp_addr);
input		lbp_write;
input	[5:0] 	lbp_addr;
input	[7:0]	lbp_data;

reg [7:0] LBP_M [0:63];
integer i;

initial begin
	for (i=0; i<=63; i=i+1) LBP_M[i] = 0;
end

always@(posedge lbp_write) 
	LBP_M[ lbp_addr ] <= lbp_data;

endmodule



module gray_mem (gray_addr, gray_req, gray_data, clk);
input	[5:0]	gray_addr;
input		gray_req;
output	[7:0]	gray_data;
input		clk;
`define PAT        "./pattern1.dat"  
reg	[7:0]	gray_data;

reg [7:0] GRAY_M [0:63];

initial	$readmemh (`PAT, GRAY_M);

always@(negedge clk) 
	if (gray_req) gray_data <= GRAY_M[ gray_addr ] ;

endmodule





module LBP (
    input         clk,
    input         reset,
    input  [7:0]  gray_data,
    output reg [5:0] gray_addr,
    output reg       gray_req,
    output reg [5:0] lbp_addr,
    output reg       lbp_write,
    output reg [7:0] lbp_data,
    output reg       finish
);

    reg [2:0] current_state, next_state; // Increased bit width for states
    parameter IDLE   = 3'd0; 
    parameter READ   = 3'd1; 
    parameter CAL    = 3'd2; 
    parameter WRITE  = 3'd3; 
    parameter DONE   = 3'd4; 

    // Coordinates for the CENTER pixel being processed
    // We only process 1 to 6 (ignoring the 0 and 7 border)
    reg [2:0] x, y; 
    reg [3:0] read_cnt; // Counter to read 9 neighbors (0-8)

    // Storage for the 3x3 window (9 pixels, 8 bits each)
    reg [7:0] window_data [0:8]; 

    // The address of the current center pixel
    wire [5:0] center_addr;
    // ANSWER TO YOUR QUESTION:
    // Since x and y are 3 bits, {y, x} is equivalent to y*8 + x
    assign center_addr = {y, x}; 

    // ==========================================
    // FSM State Register
    // ==========================================
    always @(posedge clk or posedge reset) begin
        if (reset) current_state <= IDLE;
        else       current_state <= next_state;
    end

    // ==========================================
    // Next State Logic
    // ==========================================
    always @(*) begin
        case (current_state)
            IDLE : next_state = READ;
            READ : begin
                // We need to read 9 pixels. If count reaches 9, we are done reading.
                if (read_cnt == 9) next_state = CAL;
                else next_state = READ;
            end
            CAL  : next_state = WRITE;
            WRITE: begin
                // If we finished the last pixel (6,6), we are DONE
                if (y == 6 && x == 6) next_state = DONE;
                else next_state = IDLE; // Go back to process next pixel
            end
            DONE : next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // ==========================================
    // Coordinate & Loop Control
    // ==========================================
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            x <= 3'd1; // Start at 1 (skip left border)
            y <= 3'd1; // Start at 1 (skip top border)
        end else if (current_state == WRITE) begin
            if (x == 6) begin
                if (y != 6) begin
                    x <= 3'd1;
                    y <= y + 1;
                end
                // If y==6 and x==6, we stay there (logic handled in FSM)
            end else begin
                x <= x + 1;
            end
        end
    end

    // ==========================================
    // READ LOGIC (The most complex part)
    // ==========================================
    
    // We need to generate the addresses for:
    // (x-1, y-1), (x, y-1), (x+1, y-1) ... etc
    reg [2:0] target_x, target_y;

    always @(*) begin
        // Calculate relative coordinates based on read_cnt
        // This maps 0..8 to the 3x3 grid around (x,y)
        case(read_cnt)
            0: begin target_x = x-1; target_y = y-1; end // Top-Left
            1: begin target_x = x;   target_y = y-1; end // Top-Mid
            2: begin target_x = x+1; target_y = y-1; end // Top-Right
            3: begin target_x = x-1; target_y = y;   end // Mid-Left
            4: begin target_x = x;   target_y = y;   end // Center
            5: begin target_x = x+1; target_y = y;   end // Mid-Right
            6: begin target_x = x-1; target_y = y+1; end // Bot-Left
            7: begin target_x = x;   target_y = y+1; end // Bot-Mid
            8: begin target_x = x+1; target_y = y+1; end // Bot-Right
            default: begin target_x=x; target_y=y; end
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if(reset) begin
            read_cnt <= 0;
            gray_req <= 0;
            gray_addr <= 0;
        end else if (current_state == IDLE) begin
            read_cnt <= 0; // Reset counter for new pixel
        end else if (current_state == READ) begin
            if (read_cnt < 9) begin
                gray_req  <= 1;
                gray_addr <= {target_y, target_x}; // Output address
                
                // Note: This logic assumes 0-cycle memory latency (data ready immediately)
                // If your memory has 1-cycle latency, you need to capture data 
                // in the NEXT cycle. Assuming simplified testbench behavior here:
                window_data[read_cnt] <= gray_data; 
                
                read_cnt <= read_cnt + 1;
            end
        end
    end

    // ==========================================
    // CALCULATION (Combinational Thresholding)
    // ==========================================
    wire [7:0] center_pixel;
    assign center_pixel = window_data[4]; // Index 4 is the center
    wire [7:0] bits;

    assign bits[0] = (window_data[0] >= center_pixel);
    assign bits[1] = (window_data[1] >= center_pixel);
    assign bits[2] = (window_data[2] >= center_pixel);
    assign bits[3] = (window_data[3] >= center_pixel);
    // Skip index 4 (center)
    assign bits[4] = (window_data[5] >= center_pixel);
    assign bits[5] = (window_data[6] >= center_pixel);
    assign bits[6] = (window_data[7] >= center_pixel);
    assign bits[7] = (window_data[8] >= center_pixel);

    always @(posedge clk or posedge reset) begin
        if(reset) lbp_data <= 0;
        else if (current_state == CAL) begin
            // Reverse order typically depends on spec, usually bit0 is top-left
            lbp_data <= bits; 
        end
    end

    // ==========================================
    // WRITE RESULT
    // ==========================================
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            lbp_write <= 0;
            lbp_addr <= 0;
        end else if (current_state == WRITE) begin
            lbp_write <= 1;
            lbp_addr  <= center_addr; // Write back to the center location
        end else begin
            lbp_write <= 0;
        end
    end

    // ==========================================
    // FINISH SIGNAL
    // ==========================================
    always @(posedge clk or posedge reset) begin
        if(reset) finish <= 0;
        else if (current_state == DONE) finish <= 1;
    end

endmodule










