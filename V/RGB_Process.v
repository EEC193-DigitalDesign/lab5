module RGB_Process(
	input  [7:0] raw_VGA_R,
	input  [7:0] raw_VGA_G,
	input  [7:0] raw_VGA_B,
	input  [12:0] row,
	input  [12:0] col,
	input [9:0] SW, 
	input CLK_50,
	input [3:0] KEY,

	output reg [7:0] o_VGA_R,
	output reg [7:0] o_VGA_G,
	output reg [7:0] o_VGA_B
);

wire [15:0] luminosity;
wire [7:0] grayscale_value;

assign luminosity = raw_VGA_R * 54 + raw_VGA_G * 183 + raw_VGA_B * 18; // calculate luminosity for grayscale conversion
assign grayscale_value = luminosity[15:8]; // divide by 256 to get the grayscale value

// --- Cursor Coordinate Registers ---
reg [10:0] cur1_x = 11'd300; // Start near the middle
reg [10:0] cur1_y = 11'd240;
reg [10:0] cur2_x = 11'd350; 
reg [10:0] cur2_y = 11'd240;

// --- Speed Control Counter ---
// 50,000,000 Hz / 500,000 = 100 Hz movement tick
reg [19:0] speed_cnt = 20'd0;
wire move_tick = (speed_cnt == 20'd500_000);

always @(posedge CLK_50) begin
    if (move_tick) begin
        speed_cnt <= 20'd0; // Reset counter
        
        // Use SW[8] to select which cursor to move
        if (SW[8] == 1'b0) begin 
            // --- Move Cursor 1 (3x3 block) ---
            // KEYs are active-low (0 when pressed). Boundary checks keep it on screen.
            if (~KEY[0] && cur1_x < 11'd614) cur1_x <= cur1_x + 1; // Right
            if (~KEY[3] && cur1_x > 11'd0)   cur1_x <= cur1_x - 1; // Left
            if (~KEY[1] && cur1_y < 11'd475) cur1_y <= cur1_y + 1; // Down
            if (~KEY[2] && cur1_y > 11'd0)   cur1_y <= cur1_y - 1; // Up
            
        end else begin
            // --- Move Cursor 2 (10x10 border box) ---
            if (~KEY[0] && cur2_x < 11'd607) cur2_x <= cur2_x + 1; // Right
            if (~KEY[3] && cur2_x > 11'd0)   cur2_x <= cur2_x - 1; // Left
            if (~KEY[1] && cur2_y < 11'd468) cur2_y <= cur2_y + 1; // Down
            if (~KEY[2] && cur2_y > 11'd0)   cur2_y <= cur2_y - 1; // Up
        end
    end else begin
        speed_cnt <= speed_cnt + 1;
    end
end


always @(*)begin
if (row >= 13'd0 && row < 13'd5 && col>=13'd0 && col < 13'd5) begin ///up left - red 
	o_VGA_R = 8'b11111111;
	o_VGA_G = 8'b00000000;
	o_VGA_B = 8'b00000000;
end

else if (row >= 13'd0 && row < 13'd5 && col>=13'd613 && col < 13'd617) begin //up right - Green 
	o_VGA_R = 8'b00000000;
	o_VGA_G = 8'b11111111;
	o_VGA_B = 8'b00000000;

end

else if (row >= 13'd474 && row < 13'd478 && col>=13'd0 && col < 13'd5) begin //bottom left - Blue
	o_VGA_R = 8'b00000000;
	o_VGA_G = 8'b00000000;
	o_VGA_B = 8'b11111111;

end

else if (row < 13'd478 && col < 13'd617) begin // main camera feed area     
        // Check if the current pixel being drawn is inside Cursor 1 (3x3 solid block)
        if (col >= cur1_x && col < cur1_x + 3 && row >= cur1_y && row < cur1_y + 3) begin
            o_VGA_R = 8'b00000000;
            o_VGA_G = 8'b00000000; // Green
            o_VGA_B = 8'b11111111; // Blue
        end
        // Check if the pixel is inside Cursor 2 (10x10 hollow box)
        else if (col >= cur2_x && col < cur2_x + 10 && row >= cur2_y && row < cur2_y + 10 &&
                (col == cur2_x || col == cur2_x + 9 || row == cur2_y || row == cur2_y + 9)) begin
            o_VGA_R = 8'b00000000;
            o_VGA_G = 8'b11111111; // Green
            o_VGA_B = 8'b00000000; // Blue
        end
        // If not a cursor pixel, draw the normal camera feed with your switches
        else begin
            	case (SW[2:1])
					2'b00: o_VGA_R = raw_VGA_R;
					2'b01: o_VGA_R = raw_VGA_R >> 1;
					2'b10: o_VGA_R = raw_VGA_R >> 2;
					2'b11: o_VGA_R = 8'b00000000;
				endcase

				case (SW[4:3])
					2'b00: o_VGA_G = raw_VGA_G;
					2'b01: o_VGA_G = raw_VGA_G >> 1;
					2'b10: o_VGA_G = raw_VGA_G >> 2;
					2'b11: o_VGA_G = 8'b00000000;
				endcase

				case (SW[6:5])
					2'b00: o_VGA_B = raw_VGA_B;
					2'b01: o_VGA_B = raw_VGA_B >> 1;
					2'b10: o_VGA_B = raw_VGA_B >> 2;
					2'b11: o_VGA_B = 8'b00000000;
				endcase

				case (SW[7])
					1'b0: begin
						o_VGA_R = o_VGA_R;
						o_VGA_G = o_VGA_G;
						o_VGA_B = o_VGA_B;
					end
					1'b1: begin
						o_VGA_R = grayscale_value;
						o_VGA_G = grayscale_value;
						o_VGA_B = grayscale_value;
					end
			endcase
        end

    end

else begin //camera out of the range should always be 0
	o_VGA_R = 8'b000000000;
	o_VGA_G = 8'b000000000;
	o_VGA_B = 8'b000000000;

	end
end

endmodule
