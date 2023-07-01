`define PSRAM_USE_MODULE

`ifdef PSRAM_USE_MODULE
module Pico_PSRAM (
    input  clk_osc,
    input  hclk_mem,
    input  pll_lock,
    input  resetn,
    output init_calib,
    output mclk_out,

    input mem_s_valid,
    input [31:0] mem_s_addr,
    input [31:0] mem_s_wdata,
    input [3:0] mem_s_wstrb,
    output [31:0] mem_s_rdata,
    output mem_s_ready,

    output [ 1:0] O_psram_ck,
    output [ 1:0] O_psram_ck_n,
    inout  [15:0] IO_psram_dq,
    inout  [ 1:0] IO_psram_rwds,
    output [ 1:0] O_psram_cs_n,
    output [ 1:0] O_psram_reset_n
);

    reg cmd_en_i;
    reg cmd_i;
    reg [20:0] addr_i;
    reg [63:0] wrdata_i;
    wire [63:0] rd_data;
    reg [7:0] data_mask_i;
    wire rd_data_valid;

    PSRAM_Memory_Interface_HS_Top your_instance_name (
        .clk            (clk_osc),          //input clk
        .memory_clk     (hclk_mem),         //input memory_clk
        .pll_lock       (pll_lock),         //input pll_lock
        .rst_n          (resetn),           //input rst_n
        .O_psram_ck     (O_psram_ck),       //output [1:0] O_psram_ck
        .O_psram_ck_n   (O_psram_ck_n),     //output [1:0] O_psram_ck_n
        .IO_psram_dq    (IO_psram_dq),      //inout [15:0] IO_psram_dq
        .IO_psram_rwds  (IO_psram_rwds),    //inout [1:0] IO_psram_rwds
        .O_psram_cs_n   (O_psram_cs_n),     //output [1:0] O_psram_cs_n
        .O_psram_reset_n(O_psram_reset_n),  //output [1:0] O_psram_reset_n
        .wr_data        (wrdata_i),         //input [63:0] wr_data
        .rd_data        (rd_data),          //output [63:0] rd_data
        .rd_data_valid  (rd_data_valid),    //output rd_data_valid
        .addr           (addr_i),           //input [20:0] addr
        .cmd            (cmd_i),            //input cmd
        .cmd_en         (cmd_en_i),         //input cmd_en
        .init_calib     (init_calib),       //output init_calib
        .clk_out        (mclk_out),         //output clk_out
        .data_mask      (data_mask_i)       //input [7:0] data_mask
    );

    reg [1:0] state;  // 0: write a byte, 1: read the byte back
    reg [5:0] cycle;  // 14 cycles between write and read
    reg [31:0] read_back;
    reg [7:0] read_count;
    reg completed;

    assign mem_s_ready = completed;
    assign mem_s_rdata = read_back;
    assign sys_resetn  = resetn;

    always @(posedge mclk_out) begin
        if (!sys_resetn) begin
            state <= 2'b00;
            cycle <= 8'b0;
            cmd_en_i <= 0;
            read_back <= 0;
            completed <= 0;
        end else begin
            case (state)
                default:    // 2'b00:
				begin
                    // if mem_s_valid -> state change: 11 == wbp_write, 10 == wbp_read
                    if (mem_s_valid) begin
                        addr_i[20:0] <= mem_s_addr[22:2];
                        cycle <= 0;
                        completed <= 0;
                        if (mem_s_wstrb != 0) begin
                            state <= 2'b11;  // set to write_state
                            data_mask_i <= {
                                2'b11,
                                ~mem_s_wstrb[3],
                                ~mem_s_wstrb[1],
                                2'b11,
                                ~mem_s_wstrb[2],
                                ~mem_s_wstrb[0]
                            };
                            wrdata_i <= mem_s_wdata;
                            cmd_i <= 1;
                        end else begin
                            state <= 2'b10;  // set to read_State
                            data_mask_i <= 0;
                            read_count <= 0;
                            cmd_i <= 0;
                        end
                        cmd_en_i <= 1;
                    end
                end
                2'b11: begin  // wbp_write state
                    cycle <= cycle + 6'b1;
                    if (cycle == 13) begin
                        // IPUG 943 - Table 4-2, Tcmd is 14 when burst==16
                        cycle <= 0;
                        state <= 0;
                        completed <= 1;
                    end
                    cmd_en_i <= 0;
                    data_mask_i <= 8'hff;  // stop writing after 32-bits (4-bytes)
                end
                2'b10: begin  // wbp_read state
                    if (cycle != 8'b11_1111) cycle <= cycle + 1'b1;
                    if (cycle == 0) begin
                        cmd_i <= 0;
                        cmd_en_i <= 1;
                    end else begin
                        cmd_en_i <= 0;
                        if (rd_data_valid) begin
                            read_count <= read_count + 1'b1;
                            if (read_count == 0) begin
                                //read_back[15:0] <= rd_data[15:0]; // is good
                            end else if (read_count == 1) begin
                                //read_back[31:16] <= rd_data[31:16]; // is good
                                // instead of two 16-bit word, readback of single 32-bit word is also good
                                read_back[31:0] <= rd_data[31:0];
                            end else if (read_count == 2) begin
                                //read_back[47:32] <= rd_data[47:32];
                            end else if (read_count == 3) begin
                                //read_back[63:48] <= rd_data[63:48];
                                completed <= 1;
                                state <= 0;
                            end
                        end
                    end
                end
            endcase
        end
    end

endmodule
`endif






module VGAMod (
    input CLK,
    input nRST,

    input PixelClk,

    output LCD_DE,
    output LCD_HSYNC,
    output LCD_VSYNC,

    output [4:0] LCD_B,
    output [5:0] LCD_G,
    output [4:0] LCD_R
);

    reg [15:0] PixelCount;
    reg [15:0] LineCount;

    //pulse include in back pluse; t=pluse, sync act; t=bp, data act; t=bp+height, data end
    localparam V_BackPorch = 16'd0;  //6
    localparam V_Pulse = 16'd5;
    localparam HeightPixel = 16'd600;
    localparam V_FrontPorch = 16'd45;  //62

    localparam H_BackPorch = 16'd182;
    localparam H_Pulse = 16'd1;
    localparam WidthPixel = 16'd1024;
    localparam H_FrontPorch = 16'd210;

    localparam Width_bar = 45;
    reg [15:0] BarCount;

    localparam PixelForHS = WidthPixel + H_BackPorch + H_FrontPorch;
    localparam LineForVS = HeightPixel + V_BackPorch + V_FrontPorch;

    always @(posedge PixelClk or negedge nRST) begin
        if (!nRST) begin
            LineCount  <= 16'b0;
            PixelCount <= 16'b0;
        end else if (PixelCount == PixelForHS) begin
            PixelCount <= 16'b0;
            LineCount  <= LineCount + 1'b1;
        end else if (LineCount == LineForVS) begin
            LineCount  <= 16'b0;
            PixelCount <= 16'b0;
        end else PixelCount <= PixelCount + 1'b1;
    end

    reg [9:0] Data_R;
    reg [9:0] Data_G;
    reg [9:0] Data_B;

    always @(posedge PixelClk or negedge nRST) begin
        if (!nRST) begin
            Data_R   <= 9'b0;
            Data_G   <= 9'b0;
            Data_B   <= 9'b0;
            BarCount <= 9'd5;
        end else begin
        end
    end

    assign LCD_HSYNC = (( PixelCount >= H_Pulse)&&( PixelCount <= (PixelForHS-H_FrontPorch))) ? 1'b0 : 1'b1;
    assign LCD_VSYNC = (((LineCount >= V_Pulse) && (LineCount <= (LineForVS - 0)))) ? 1'b0 : 1'b1;
    //assign  FIFO_RST  = (( PixelCount ==0)) ? 1'b1 : 1'b0;

    assign  LCD_DE  = (  ( PixelCount >= H_BackPorch )&&
                        ( PixelCount <= PixelForHS-H_FrontPorch ) &&
                        ( LineCount >= V_BackPorch ) &&
                        ( LineCount <= LineForVS-V_FrontPorch-1 ))  ? 1'b1 : 1'b0;

    assign  LCD_R   =   (PixelCount<Width_bar*BarCount)? 5'b00000 :  
                        (PixelCount<(Width_bar*(BarCount+1)) ? 5'b00001 :    
                        (PixelCount<(Width_bar*(BarCount+2)) ? 5'b00010 :    
                        (PixelCount<(Width_bar*(BarCount+3)) ? 5'b00100 :    
                        (PixelCount<(Width_bar*(BarCount+4)) ? 5'b01000 :    
                        (PixelCount<(Width_bar*(BarCount+5)) ? 5'b10000 :  5'b00000 )))));

    assign  LCD_G   =   (PixelCount<(Width_bar*(BarCount+5)))? 6'b000000 : 
                        (PixelCount<(Width_bar*(BarCount+6)) ? 6'b000001 :    
                        (PixelCount<(Width_bar*(BarCount+7)) ? 6'b000010 :    
                        (PixelCount<(Width_bar*(BarCount+8)) ? 6'b000100 :    
                        (PixelCount<(Width_bar*(BarCount+9)) ? 6'b001000 :    
                        (PixelCount<(Width_bar*(BarCount+10)) ? 6'b010000 :  
                        (PixelCount<(Width_bar*(BarCount+11)) ? 6'b100000 : 6'b000000 ))))));

    assign  LCD_B   =   (PixelCount<(Width_bar*(BarCount+11)))? 5'b00000 : 
                        (PixelCount<(Width_bar*(BarCount+12)) ? 5'b00001 :    
                        (PixelCount<(Width_bar*(BarCount+13)) ? 5'b00010 :    
                        (PixelCount<(Width_bar*(BarCount+14)) ? 5'b00100 :    
                        (PixelCount<(Width_bar*(BarCount+15)) ? 5'b01000 :    
                        (PixelCount<(Width_bar*(BarCount+16)) ? 5'b10000 :  5'b00000 )))));

endmodule
