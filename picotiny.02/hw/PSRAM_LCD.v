module PSRAM_FRAMEBUFFER_LCD (
    input clk,
    input resetn,
    input pclk,

    input lcdmem_s_valid,
    input [31:0] lcdmem_s_addr,
    input [31:0] lcdmem_s_wdata,
    input [3:0] lcdmem_s_wstrb,
    output [31:0] lcdmem_s_rdata,
    output lcdmem_s_ready,

    output LCD_DE,
    output LCD_HSYNC,
    output LCD_VSYNC,
    output [4:0] LCD_B,
    output [5:0] LCD_G,
    output [4:0] LCD_R,

    input  clk_osc,
    input  hclk_mem,
    input  pll_lock,
    // input  resetn,
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
    localparam LCD_WIDTH = 16'd1024;
    localparam LCD_HEIGHT = 16'd600;

    localparam H_FrontPorch = 16'd210;
    localparam H_PulseWidth = 16'd16;
    localparam H_BackPorch = 16'd182;

    localparam V_FrontPorch = 16'd45;
    localparam V_PulseWidth = 16'd5;
    localparam V_BackPorch = 16'd0;

    localparam BarCount = 9'd5;
    localparam Width_bar = 45;

    reg  [10:0] CounterX;
    reg  [ 9:0] CounterY;
    wire [10:0] PixelCount = CounterX;
    wire [10:0] dma_raddr = CounterX;

    reg vga_HS, vga_VS, inDisplayArea;
    reg [4:0] Data_R;
    reg [5:0] Data_G;
    reg [4:0] Data_B;
    wire [15:0] dout_o;
    reg framestart;

    wire CounterXmaxed = (CounterX == (LCD_WIDTH + H_FrontPorch + H_PulseWidth + H_BackPorch));
    wire CounterYmaxed = (CounterY == (LCD_HEIGHT + V_FrontPorch + V_PulseWidth + V_BackPorch));

    always @(posedge pclk)
        if (CounterXmaxed) CounterX <= 0;
        else CounterX <= CounterX + 1'b1;

    always @(posedge pclk) begin
        if (CounterXmaxed) begin
            if (CounterYmaxed) CounterY <= 0;
            else CounterY <= CounterY + 1'b1;
        end
    end

    always @(posedge pclk) begin
        vga_HS <= (CounterX > (LCD_WIDTH + H_FrontPorch) && (CounterX < (LCD_WIDTH + H_FrontPorch + H_PulseWidth)));  // active for 96 clocks
        vga_VS <= (CounterY > (LCD_HEIGHT+V_FrontPorch) && (CounterY < (LCD_HEIGHT+V_FrontPorch+V_PulseWidth)));  // active for 2 clocks
    end

    always @(posedge pclk) begin
        inDisplayArea <= (CounterX > 0 && CounterX <= LCD_WIDTH) && (CounterY > 0 && CounterY <= LCD_HEIGHT);
        Data_R <= dout_o[15:11];
        Data_G <= dout_o[10:5];
        Data_B <= dout_o[4:0];
    end

    assign LCD_HSYNC = ~vga_HS;
    assign LCD_VSYNC = ~vga_VS;
    assign LCD_DE = inDisplayArea;
    assign LCD_R = Data_R;
    assign LCD_G = Data_G;
    assign LCD_B = Data_B;

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

    reg [1:0] state;
    reg [5:0] cycle;  // 14 cycles between write and read
    reg [31:0] read_back;
    reg [7:0] read_count;
    reg completed;

    assign mem_s_ready = completed;
    assign mem_s_rdata = read_back;
    assign sys_resetn = resetn;
    // write enables are negated for data_mask bits
    assign we0 = ~mem_s_wstrb[0];
    assign we1 = ~mem_s_wstrb[1];
    assign we2 = ~mem_s_wstrb[2];
    assign we3 = ~mem_s_wstrb[3];

    /* To get a linear readback from the words written, brute-force
     * remapping of the write location was worked out here. */
    wire [2:0] w_remap[0:7];
    assign w_remap[0] = 3'd0;  //good
    assign w_remap[1] = 3'd7;
    assign w_remap[2] = 3'd2;  //good
    assign w_remap[3] = 3'd1;
    assign w_remap[4] = 3'd4;  //good
    assign w_remap[5] = 3'd3;
    assign w_remap[6] = 3'd6;  //good
    assign w_remap[7] = 3'd5;

    reg [2:0] vdma_start_sr;
    reg [7:0] vdma_waddr;
    reg [63:0] vdma_wdata;
    reg vdma_wstrb;
    reg vdma_waitinc;
    reg [7:0] vdma_blkcnt;
    reg [9:0] vdma_lineidx;
    localparam VDMA_MAXBLKCNT = 8'd64;

    wire vdma_read = (vdma_start_sr[2:1] == 2'b01);

    always @(posedge mclk_out) begin
        if (!sys_resetn) begin
            state <= 2'b00;
            cycle <= 8'b0;
            cmd_en_i <= 0;
            read_back <= 0;
            completed <= 0;
            vdma_wstrb <= 0;
            vdma_waitinc <= 0;
            vdma_start_sr <= 0;
            vdma_blkcnt <= 0;
            vdma_lineidx <= 0;
        end else begin
            // vdma_start_sr = {vdma_start_sr[1:0], vga_HS && (CounterY < LCD_HEIGHT)};
            vdma_start_sr = {vdma_start_sr[1:0], vga_HS};
            case (state)
                default:    // 2'b00:
                begin
                    /* if mem_s_valid -> state change: 01 == wbp_write, 10 == wbp_read, 11 == vdma_read */
                    cycle <= 0;
                    completed <= 0;
                    vdma_wstrb <= 0;

                    if (vdma_start_sr[2:1] == 2'b01) begin
                        if (CounterY < LCD_HEIGHT) begin
                            // i.e. 0 < CounterY < 600
                            state        <= 2'b11;  // set to vdma_read_State
                            addr_i       <= {vdma_lineidx, vdma_blkcnt[5:0], 3'b0};
                            data_mask_i  <= 'b0;
                            read_count   <= 0;
                            cmd_i        <= 0;
                            cmd_en_i     <= 1;
                            vdma_waitinc <= 0;
                            vdma_blkcnt  <= 0;
                        end else begin
                            vdma_lineidx <= 0;
                        end
                    end else if (vdma_blkcnt > 0 && vdma_blkcnt < VDMA_MAXBLKCNT) begin
                        state        <= 2'b11;  // set to vdma_read_State
                        addr_i       <= {vdma_lineidx, vdma_blkcnt[5:0], 3'b0};
                        data_mask_i  <= 'b0;
                        read_count   <= 0;
                        cmd_i        <= 0;
                        cmd_en_i     <= 1;
                        vdma_waitinc <= 0;
                    end else if (mem_s_valid) begin
                        if (mem_s_wstrb != 0) begin
                            /* First cycle of write setup: because the CPU only
                             * writes 32-bit words, only the first setted-up
                             * address is written, the rest of the wasted burst
                             * are masked off */
                            state <= 2'b01;  // set to write_state
                            addr_i[20:0] <= {mem_s_addr[22:5], w_remap[mem_s_addr[4:2]]};
                            wrdata_i <= mem_s_wdata;
                            data_mask_i <= {2'b11, we3, we1, 2'b11, we2, we0};
                            cmd_i <= 1;
                            cmd_en_i <= 1;
                        end else begin
                            /* First cycle of read setup: here all 32-bit words
                             * of the burst are read back, but only the relevant
                             * one is given back to the CPU. */
                            state        <= 2'b10;  // set to read_State
                            addr_i[20:0] <= (mem_s_addr[22:2] & 21'b1_1111_1111_1111_1111_1000);
                            data_mask_i  <= 'b0;
                            read_count   <= 0;
                            cmd_i        <= 0;
                            cmd_en_i     <= 1;
                        end
                    end else begin

                    end
                end
                2'b01: begin  // wbp_write state
                    cmd_en_i <= 0;
                    cycle <= cycle + 1'b1;
                    case (cycle)
                        default: begin
                            // stop writing after the first 32-bit word
                            data_mask_i <= 8'hff;
                        end
                        13: begin
                            // IPUG 943 - Table 4-2, Tcmd is 14 when burst==16
                            completed <= 1;
                            cycle <= 0;
                            state <= 0;
                        end
                    endcase
                end
                2'b10: begin  // wbp_read state
                    cmd_en_i <= 0;
                    if (rd_data_valid) begin
                        read_count <= read_count + 1'b1;
                        case (read_count)
                            0: begin
                                if (mem_s_addr[4:3] == 2'b00) begin
                                    if (~mem_s_addr[2]) read_back[31:0] <= rd_data[31:0];
                                    else read_back[31:0] <= rd_data[63:32];
                                end
                            end
                            1: begin
                                if (mem_s_addr[4:3] == 2'b01) begin
                                    if (~mem_s_addr[2]) read_back[31:0] <= rd_data[31:0];
                                    else read_back[31:0] <= rd_data[63:32];
                                end
                            end
                            2: begin
                                if (mem_s_addr[4:3] == 2'b10) begin
                                    if (~mem_s_addr[2]) read_back[31:0] <= rd_data[31:0];
                                    else read_back[31:0] <= rd_data[63:32];
                                end
                            end
                            3: begin
                                if (mem_s_addr[4:3] == 2'b11) begin
                                    if (~mem_s_addr[2]) read_back[31:0] <= rd_data[31:0];
                                    else read_back[31:0] <= rd_data[63:32];
                                end
                                completed <= 1;
                                state <= 0;
                            end
                            default: begin
                                completed <= 1;
                                state <= 0;
                            end
                        endcase
                    end
                end
                2'b11: begin  // vdma_read state
                    cmd_en_i <= 0;
                    cycle <= cycle + 1'b1;
                    if (rd_data_valid) begin
                        read_count <= read_count + 1'b1;
                        vdma_waddr <= {vdma_blkcnt[5:0], read_count[1:0]};
                        vdma_wdata <= rd_data;
                        vdma_wstrb <= 1'b1;
                        if (read_count == 7'd3) begin
                            state <= 0;
                            if (vdma_blkcnt == (VDMA_MAXBLKCNT - 1))
                                vdma_lineidx <= vdma_lineidx + 1'b1;
                            vdma_blkcnt  <= vdma_blkcnt + 1'b1;
                            vdma_waitinc <= 1;
                        end
                    end
                end
            endcase
        end
    end

    Gowin_DPB_256x64_1024x16 linebuf_256x64 (
        .clka  (mclk_out),  //input clka
        .reseta(~resetn),   //input reseta

        .cea(1'b1),  //input cea
        .wrea(vdma_wstrb),  //input wrea
        .ocea(1'b0),  //input ocea
        .ada(vdma_waddr),  //input [7:0] ada
        .dina(vdma_wdata),  //input [63:0] dina

        /* Read-only Port B for line pixels */
        .clkb(pclk),  //input clkb
        .resetb(~resetn),  //input resetb
        .ceb(1'b1),  //input ceb
        .wreb(1'b0),  //input wreb
        .oceb(1'b0),  //input oceb
        .adb(dma_raddr[9:0]),  //input [9:0] adb
        .dinb(16'b0),
        .doutb(dout_o)  //output [15:0] doutb
    );

endmodule

