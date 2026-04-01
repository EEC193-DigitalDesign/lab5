//=======================================================
//  lab 5 part 2
//=======================================================

module DE1_SOC_D8M_LB_RTL(
    input                       CLOCK2_50,
    input                       CLOCK3_50,
    input                       CLOCK4_50,
    input                       CLOCK_50,
    output             [6:0]    HEX0,
    output             [6:0]    HEX1,
    output             [6:0]    HEX2,
    output             [6:0]    HEX3,
    output             [6:0]    HEX4,
    output             [6:0]    HEX5,
    input              [3:0]    KEY,
    output             [9:0]    LEDR,
    input              [9:0]    SW,
    output                      VGA_BLANK_N,
    output             [7:0]    VGA_B,
    output                      VGA_CLK,
    output             [7:0]    VGA_G,
    output                      VGA_HS,
    output             [7:0]    VGA_R,
    output                      VGA_SYNC_N,
    output                      VGA_VS,
    inout                       CAMERA_I2C_SCL,
    inout                       CAMERA_I2C_SDA,
    output                      CAMERA_PWDN_n,
    output                      MIPI_CS_n,
    inout                       MIPI_I2C_SCL,
    inout                       MIPI_I2C_SDA,
    output                      MIPI_MCLK,
    input                       MIPI_PIXEL_CLK,
    input              [9:0]    MIPI_PIXEL_D,
    input                       MIPI_PIXEL_HS,
    input                       MIPI_PIXEL_VS,
    output                      MIPI_REFCLK,
    output                      MIPI_RESET_n
);

// Intermediate Wires
wire        RESET_N;
wire [7:0]  sCCD_R, sCCD_G, sCCD_B;
wire [15:0] H_Cont, V_Cont;
wire        READ_Request;
wire        I2C_RELEASE;
wire        CAMERA_I2C_SCL_MIPI, CAMERA_I2C_SCL_AF;
wire        CAMERA_MIPI_RELAESE, MIPI_BRIDGE_RELEASE;
wire [7:0]  VGA_R_A, VGA_G_A, VGA_B_A;
wire [7:0]  VGA_R_OUT, VGA_G_OUT, VGA_B_OUT; 
wire        VGA_CLK_25M;
wire        D8M_CK_HZ, D8M_CK_HZ2, D8M_CK_HZ3;

assign MIPI_RESET_n   = RESET_N;
assign CAMERA_PWDN_n  = SW[1]; 
assign MIPI_CS_n      = 0;

// Reset Delay
RESET_DELAY u2 (
    .iRST   ( ~SW[0] ), 
    .iCLK   ( CLOCK2_50 ),
    .oREADY ( RESET_N )
);

// I2C Config (Standard Skeleton)
assign I2C_RELEASE    = CAMERA_MIPI_RELAESE & MIPI_BRIDGE_RELEASE;
assign CAMERA_I2C_SCL = (I2C_RELEASE) ? CAMERA_I2C_SCL_AF : CAMERA_I2C_SCL_MIPI;

MIPI_BRIDGE_CAMERA_Config cfin(
    .RESET_N            ( RESET_N ),
    .CLK_50             ( CLOCK2_50 ),
    .MIPI_I2C_SCL       ( MIPI_I2C_SCL ),
    .MIPI_I2C_SDA       ( MIPI_I2C_SDA ),
    .MIPI_I2C_RELEASE   ( MIPI_BRIDGE_RELEASE ),
    .CAMERA_I2C_SCL     ( CAMERA_I2C_SCL_MIPI ),
    .CAMERA_I2C_SDA     ( CAMERA_I2C_SDA ),
    .CAMERA_I2C_RELAESE ( CAMERA_MIPI_RELAESE )
);

// PLLs (Standard Skeleton)
pll_test ref( .refclk(CLOCK_50), .rst(1'b0), .outclk_0(MIPI_REFCLK) );
vga_pll pllv( .refclk(CLOCK4_50), .rst(1'b0), .outclk_0(VGA_CLK_25M) );

// RAW to RGB
D8M_SET ccd (
    .RESET_SYS_N(RESET_N), .CLOCK_50(CLOCK2_50), .CCD_DATA(MIPI_PIXEL_D),
    .CCD_FVAL(MIPI_PIXEL_VS), .CCD_LVAL(MIPI_PIXEL_HS), .CCD_PIXCLK(MIPI_PIXEL_CLK),
    .READ_EN(READ_Request), .VGA_CLK(VGA_CLK), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS),
    .X_Cont(H_Cont), .Y_Cont(V_Cont), .sCCD_R(sCCD_R), .sCCD_G(sCCD_G), .sCCD_B(sCCD_B)
);

//=======================================================
//  Part 2 Logic: Cursor Generation with Toggle
//=======================================================
reg [15:0] cur_x, cur_y;
reg [21:0] slow_count;
wire       move_tick = (slow_count == 22'd1000000); 

// move cursor
always @(posedge VGA_CLK or negedge RESET_N) begin
    if (!RESET_N) begin
        cur_x <= 16'd320;
        cur_y <= 16'd240;
        slow_count <= 0;
    end else begin
        slow_count <= slow_count + 1;
        if (move_tick) begin
            slow_count <= 0;
            if (!KEY[0] && cur_y > 0)   cur_y <= cur_y - 1; 
            if (!KEY[1] && cur_y < 470) cur_y <= cur_y + 1; 
            if (!KEY[2] && cur_x > 0)   cur_x <= cur_x - 1; 
            if (!KEY[3] && cur_x < 630) cur_x <= cur_x + 1; 
        end
    end
end

// shape
wire is_3x3   = (H_Cont >= cur_x && H_Cont < cur_x + 3) && 
                (V_Cont >= cur_y && V_Cont < cur_y + 3);

wire is_10x10 = ((H_Cont == cur_x || H_Cont == cur_x + 9) && (V_Cont >= cur_y && V_Cont <= cur_y + 9)) ||
                ((V_Cont == cur_y || V_Cont == cur_y + 9) && (H_Cont >= cur_x && H_Cont <= cur_x + 9));

wire draw_cursor = (SW[2]) ? is_10x10 : is_3x3;

reg [7:0] cursor_r, cursor_g, cursor_b;
always @(*) begin
    if (draw_cursor) begin
        cursor_r = 8'h00; // Cyan = Green + Blue
        cursor_g = 8'hFF;
        cursor_b = 8'hFF;
    end else begin
        cursor_r = sCCD_R;
        cursor_g = sCCD_G;
        cursor_b = sCCD_B;
    end
end

// VGA Controller
VGA_Controller_trig u1 (
    .iCLK(VGA_CLK_25M), .H_Cont(H_Cont), .V_Cont(V_Cont), .READ_Request(READ_Request),
    .iRed(cursor_r), .iGreen(cursor_g), .iBlue(cursor_b),
    .oVGA_R(VGA_R_A), .oVGA_G(VGA_G_A), .oVGA_B(VGA_B_A),
    .oVGA_H_SYNC(VGA_HS), .oVGA_V_SYNC(VGA_VS), .oVGA_SYNC(VGA_SYNC_N),
    .oVGA_BLANK(VGA_BLANK_N), .oVGA_CLOCK(VGA_CLK), .iRST_N(RESET_N)
);

// Focus Adjustment & Final Output
FOCUS_ADJ adl(
    .CLK_50(CLOCK2_50), .RESET_N(I2C_RELEASE), .RESET_SUB_N(I2C_RELEASE),
    .AUTO_FOC(KEY[3]), .SW_FUC_LINE(SW[3]), .SW_FUC_ALL_CEN(SW[3]),
    .VIDEO_HS(VGA_HS), .VIDEO_VS(VGA_VS), .VIDEO_CLK(VGA_CLK), .VIDEO_DE(READ_Request),
    .iR(VGA_R_A), .iG(VGA_G_A), .iB(VGA_B_A), .oR(VGA_R_OUT), .oG(VGA_G_OUT), .oB(VGA_B_OUT), 
    .READY(READY), .SCL(CAMERA_I2C_SCL_AF), .SDA(CAMERA_I2C_SDA)
);

assign VGA_R = VGA_R_OUT;
assign VGA_G = VGA_G_OUT;
assign VGA_B = VGA_B_OUT;

// Status & Monitors
FpsMonitor uFps2( .clk50(CLOCK2_50), .vs(VGA_VS), .hex_fps_h(HEX1), .hex_fps_l(HEX0) );
assign {HEX2, HEX3, HEX4, HEX5} = 28'h7FFFFFFF;
CLOCKMEM ck1 ( .CLK(VGA_CLK_25M),    .CLK_FREQ(25000000), .CK_1HZ(D8M_CK_HZ) );
CLOCKMEM ck2 ( .CLK(MIPI_REFCLK),    .CLK_FREQ(20000000), .CK_1HZ(D8M_CK_HZ2) );
CLOCKMEM ck3 ( .CLK(MIPI_PIXEL_CLK), .CLK_FREQ(25000000), .CK_1HZ(D8M_CK_HZ3) );
assign LEDR = { D8M_CK_HZ, D8M_CK_HZ2, D8M_CK_HZ3, 5'h0, CAMERA_MIPI_RELAESE, MIPI_BRIDGE_RELEASE };

endmodule