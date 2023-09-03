module PSRAM_FRAMEBUFFER_LCD (
    input clk,
    input resetn,
    input pclk,

    input reg_valid,
    input [31:0] reg_addr,
    input [31:0] reg_wdata,
    input [3:0] reg_wstrb,
    output [31:0] reg_rdata,
    output reg_ready,

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

    wire [31:0] gpu_ctrl;
    wire [22:0] disp_addr;
    wire [22:0] work_addr;
    wire [15:0] rgb565;
    wire [31:0] x0y0_point;
    wire is_busy;

    FB_Registers fb_regs (
        .cpu_clk(clk),
        .resetn(resetn),
        .mem_valid(reg_valid),
        .mem_addr(reg_addr),
        .mem_wdata(reg_wdata),
        .mem_wstrb(reg_wstrb),
        .mem_rdata(reg_rdata),
        .mem_ready(reg_ready),

        .gpu_ctrl(gpu_ctrl),
        .disp_addr(disp_addr),
        .work_addr(work_addr),
        .rgb565(rgb565),
        .x0y0_point(x0y0_point),
        .busy_i(gpu_is_busy)
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

    reg [3:0] state;
    reg [5:0] cycle;  // 14 cycles between write and read
    reg [31:0] read_back;
    reg [7:0] read_count;
    reg completed;
    localparam READ_COUNT_TOP = 2'b11;

    assign mem_s_ready = completed;
    assign mem_s_rdata = read_back;
    assign sys_resetn  = resetn;
    /* write enables are negated for data_mask bits */
    wire we0, we1, we2, we3;
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
    reg [22:0] vdma_lineaddr;
    localparam VDMA_MAXBLKCNT = 8'd64;
    localparam VDMA_LINEADDR_STRIDE = 23'd2048;
    reg [1:0] gpu_setbg_sr;
    reg gpu_setbg_start, gpu_setbg_cont;
    reg [22:0] set_bg_lineaddr;
    reg [ 7:0] set_bg_blkcnt;
    reg [ 9:0] set_bg_linecnt;
    reg [ 1:0] gpu_setpt_sr;
    reg gpu_setpt_start, gpu_setpt_cont;
    reg [7:0] set_pt_blkcnt;
    wire [15:0] x0_val, y0_val;
    wire [22:0] y0_lineaddr;
    wire [22:0] x0_blkaddr;
    wire [15:0] pm;
    wire [63:0] x0_pixelmask32;

    assign x0_val = x0y0_point[15:0];
    assign y0_val = x0y0_point[31:16];
    assign y0_lineaddr = work_addr + y0_val * VDMA_LINEADDR_STRIDE;
    assign x0_blkaddr = y0_lineaddr + ((x0_val * 2) & 16'b1111_1111_1110_0000);
    // verilog_format: off
    assign x0_pixelmask32 = ~{
                            //   pm[31],pm[30],pm[29],pm[28],pm[31],pm[30],pm[29],pm[28],
                            //   pm[27],pm[26],pm[25],pm[24],pm[27],pm[26],pm[25],pm[24],
                            //   pm[23],pm[22],pm[21],pm[20],pm[23],pm[22],pm[21],pm[20],
                            //   pm[19],pm[18],pm[17],pm[16],pm[19],pm[18],pm[17],pm[16],
                              pm[15],pm[14],pm[13],pm[12],pm[15],pm[14],pm[13],pm[12],
                              pm[11],pm[10],pm[9], pm[8], pm[11],pm[10],pm[9], pm[8],
                              pm[7], pm[6], pm[5], pm[4], pm[7], pm[6], pm[5], pm[4],
                              pm[3], pm[2], pm[1], pm[0], pm[3], pm[2], pm[1], pm[0] };
    // verilog_format: on
    // assign pm = 16'b0000_0010; // testing 2nd pixel
    assign pm = (1'b1 << x0_val[3:0]);

    assign gpu_is_busy = gpu_setbg_start | gpu_setbg_cont | gpu_setpt_start | gpu_setpt_cont;


    always @(posedge mclk_out) begin
        if (!sys_resetn) begin
            state <= 3'd0;
            cycle <= 8'b0;
            cmd_en_i <= 0;
            read_back <= 0;
            completed <= 0;
            vdma_wstrb <= 0;
            vdma_waitinc <= 0;
            vdma_start_sr <= 0;
            vdma_blkcnt <= 0;
            vdma_lineidx <= 0;
            gpu_setbg_sr <= 0;
            gpu_setbg_start <= 0;
            gpu_setbg_cont <= 0;
            set_bg_blkcnt <= 0;
            set_bg_linecnt <= 0;
            gpu_setpt_start <= 0;
            gpu_setpt_cont <= 0;
        end else begin
            vdma_start_sr = {vdma_start_sr[1:0], vga_HS};
            gpu_setbg_sr <= {gpu_setbg_sr[0], gpu_ctrl[1]};
            if (gpu_setbg_sr[1:0] == 2'b01) gpu_setbg_start <= 1;
            gpu_setpt_sr <= {gpu_setpt_sr[0], gpu_ctrl[2]};
            if (gpu_setpt_sr[1:0] == 2'b01) gpu_setpt_start <= 1;
            case (state)
                default:    /* Idle and decision-making state */
                begin
                    cycle <= 0;
                    completed <= 0;
                    vdma_wstrb <= 0;

                    if (vdma_start_sr[2:1] == 2'b01) begin
                        if (CounterY < LCD_HEIGHT) begin
                            // i.e. 0 < CounterY < 600
                            state        <= 3;  // set to vdma_read_State
                            addr_i       <= {vdma_lineaddr[22:11], vdma_blkcnt[5:0], 3'b0};
                            data_mask_i  <= 'b0;
                            read_count   <= 0;
                            cmd_i        <= 0;
                            cmd_en_i     <= 1;
                            vdma_waitinc <= 0;
                            vdma_blkcnt  <= 0;
                        end else begin
                            vdma_lineidx  <= 0;
                            vdma_lineaddr <= disp_addr;
                        end
                    end else if (vdma_blkcnt > 0 && vdma_blkcnt < VDMA_MAXBLKCNT) begin
                        state        <= 3;  // set to vdma_read_State
                        addr_i       <= {vdma_lineaddr[22:11], vdma_blkcnt[5:0], 3'b0};
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
                             * (which are possibly wrapped) are masked off */
                            state <= 1;  // set to write_state
                            addr_i[20:0] <= {mem_s_addr[22:5], w_remap[mem_s_addr[4:2]]};
                            wrdata_i <= mem_s_wdata;
                            data_mask_i <= {2'b11, we3, we1, 2'b11, we2, we0};
                            cmd_i <= 1;
                            cmd_en_i <= 1;
                        end else begin
                            /* First cycle of read setup: here all 32-bit words
                             * of the burst are read back, but only the relevant
                             * one-readcycle is given back to the CPU. */
                            state        <= 2;  // set to read_State
                            addr_i[20:0] <= (mem_s_addr[22:2] & 21'b1_1111_1111_1111_1111_1000);
                            data_mask_i  <= 'b0;
                            read_count   <= 0;
                            cmd_i        <= 0;
                            cmd_en_i     <= 1;
                        end
                    end else if (gpu_setbg_start || gpu_setbg_cont) begin
                        /* same like PSRAM write, but setup to write bgcolor */
                        state           <= 4;
                        gpu_setbg_start <= 0;
                        if (gpu_setbg_start) begin
                            gpu_setbg_cont <= 1;
                            set_bg_blkcnt <= 0;
                            set_bg_linecnt <= 0;
                            set_bg_lineaddr <= work_addr;
                            addr_i <= {work_addr[22:11], set_bg_blkcnt[5:0], 3'b0};
                        end else begin
                            addr_i <= {set_bg_lineaddr[22:11], set_bg_blkcnt[5:0], 3'b0};
                        end
                        cmd_i       <= 1;
                        cmd_en_i    <= 1;
                        wrdata_i    <= {rgb565, rgb565, rgb565, rgb565};
                        data_mask_i <= 8'h00;
                    end else if (gpu_setpt_start || gpu_setpt_cont) begin
                        state <= 5;
                        gpu_setpt_start <= 0;
                        gpu_setpt_cont <= 1;
                        // enable PSRAM write
                        cmd_i <= 1;
                        cmd_en_i <= 1;
                        // set write data same as set_bg, but mask-on the correct pixel
                        wrdata_i    <= {rgb565, rgb565, rgb565, rgb565};
                        data_mask_i <= x0_pixelmask32[7:0];
                        addr_i <= x0_blkaddr >> 2;
                    end
                end
                1: begin  /* PSRAM write state */
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
                2: begin  /* PSRAM read state */
                    cmd_en_i <= 0;
                    if (rd_data_valid) begin
                        read_count <= read_count + 1'b1;
                        if ((read_count & READ_COUNT_TOP) == ((mem_s_addr >> 3) & READ_COUNT_TOP)) begin
                            if (~mem_s_addr[2]) read_back[31:0] <= rd_data[31:0];
                            else read_back[31:0] <= rd_data[63:32];
                        end
                        if (read_count >= READ_COUNT_TOP) begin
                            completed <= 1;
                            state <= 0;
                        end
                    end
                end
                3: begin  /* Video line PSRAM-to-linebuf vdma_read state */
                    cmd_en_i <= 0;
                    cycle <= cycle + 1'b1;
                    if (rd_data_valid) begin
                        read_count <= read_count + 1'b1;
                        vdma_waddr <= {vdma_blkcnt[5:0], read_count[1:0]};
                        vdma_wdata <= rd_data;
                        vdma_wstrb <= 1'b1;
                        if (read_count == 7'd3) begin
                            state <= 0;
                            if (vdma_blkcnt == (VDMA_MAXBLKCNT - 1)) begin
                                // Note to self: don't increment vmda_lineaddr at 
                                // VDMA_BLK size, let vdma_blkcnt do that, because
                                // eventually going to use this with a FIFO instead
                                // of DPB mem.
                                vdma_lineaddr <= vdma_lineaddr + VDMA_LINEADDR_STRIDE;
                                vdma_lineidx  <= vdma_lineidx + 1'b1;
                            end
                            vdma_blkcnt  <= vdma_blkcnt + 1'b1;
                            vdma_waitinc <= 1;
                        end
                    end
                end
                4: begin
                    /* gpu_setbg: same like PSRAM write state but write mem with bgcolor */
                    cmd_en_i <= 0;
                    cycle <= cycle + 1'b1;
                    /* turn off gpu_setbg_cont when limits are reached, but can still continue on state 4 */
                    if ((set_bg_blkcnt == (VDMA_MAXBLKCNT - 1)) && (set_bg_linecnt >= (LCD_HEIGHT - 1))) begin
                        gpu_setbg_cont <= 0;
                    end
                    case (cycle)
                        default: begin
                            // keep writing all bits
                            // no need to update wrdata_i and data_mask_i
                        end
                        13: begin
                            cycle <= 0;
                            state <= 0;
                            if (set_bg_blkcnt == (VDMA_MAXBLKCNT - 1)) begin
                                set_bg_blkcnt   <= 0;
                                set_bg_linecnt  <= set_bg_linecnt + 1'b1;
                                set_bg_lineaddr <= set_bg_lineaddr + VDMA_LINEADDR_STRIDE;
                            end else begin
                                set_bg_blkcnt <= set_bg_blkcnt + 1'b1;
                            end
                        end
                    endcase
                end
                5: begin
                    /* draw a point from x0y0_reg with color_reg
                     * this will serve as a test of (a) calculating lineaddr from Y0
                     * with multiplication-and-add to workaddr_reg (b) calculating
                     * of byte(?) address and mask for pixel x-axis from X0. */
                    /* gpu_setbg: same like PSRAM write state but write mem with bgcolor */
                    cmd_en_i <= 0;
                    cycle <= cycle + 1'b1;
                    case (cycle)
                        0: data_mask_i <= x0_pixelmask32[15:8];
                        1: data_mask_i <= x0_pixelmask32[23:16];
                        2: data_mask_i <= x0_pixelmask32[31:24];
                        default: data_mask_i <= 8'hff;
                        13: begin
                            cycle <= 0;
                            state <= 0;
                            gpu_setpt_start <= 0;
                            gpu_setpt_cont <= 0;
                        end
                    endcase
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

module FB_Registers (
    input cpu_clk,
    input resetn,

    input mem_valid,
    input [31:0] mem_addr,
    input [31:0] mem_wdata,
    input [3:0] mem_wstrb,
    output mem_ready,
    output [31:0] mem_rdata,

    output [31:0] gpu_ctrl,
    output [22:0] disp_addr,
    output [22:0] work_addr,
    output [31:0] x0y0_point,
    output [15:0] rgb565,
    input busy_i
);
    reg [31:0] ctrl_stat_reg;
    reg [31:0] disp_addr_reg;
    reg [31:0] work_addr_reg;
    reg [31:0] color_reg;
    reg [31:0] x0y0_reg;
    reg [31:0] x1y1_reg;
    reg [31:0] size_reg;
    reg [31:0] rdata_r;
    reg ready_r;

    assign gpu_ctrl   = ctrl_stat_reg;
    assign disp_addr  = disp_addr_reg;
    assign work_addr  = work_addr_reg;
    assign x0y0_point = x0y0_reg;

    wire r0, g0, b0;
    assign r0 = color_reg[19] | color_reg[18] | color_reg[17] | color_reg[16];
    assign g0 = color_reg[10] | color_reg[9] | color_reg[8];
    assign b0 = color_reg[3] | color_reg[2] | color_reg[1] | color_reg[0];
    assign rgb565 = {color_reg[23:20], r0, color_reg[15:11], g0, color_reg[7:4], b0};

    always @(posedge cpu_clk) begin
        if (!resetn) begin
            ready_r <= 1'b0;
            ctrl_stat_reg <= 32'b0;
            disp_addr_reg <= 32'b0;
            work_addr_reg <= 32'b0;
            color_reg <= 32'b0;
            x0y0_reg <= 32'b0;
            x1y1_reg <= 32'b0;
            size_reg <= 32'b0;
        end else begin
            ready_r <= 1'b0;
            if (mem_valid && !ready_r) begin
                ready_r <= 1'b1;
                case (mem_addr[4:2])
                    3'd0: begin
                        if (mem_wstrb[3]) ctrl_stat_reg[31:24] <= mem_wdata[31:24];
                        if (mem_wstrb[2]) ctrl_stat_reg[24:16] <= mem_wdata[24:16];
                        if (mem_wstrb[1]) ctrl_stat_reg[15:8] <= mem_wdata[15:8];
                        if (mem_wstrb[0]) ctrl_stat_reg[7:0] <= mem_wdata[7:0];
                        rdata_r <= {ctrl_stat_reg[31:1], busy_i};
                    end
                    3'd1: begin
                        if (mem_wstrb[3]) disp_addr_reg[31:24] <= mem_wdata[31:24];
                        if (mem_wstrb[2]) disp_addr_reg[24:16] <= mem_wdata[24:16];
                        if (mem_wstrb[1]) disp_addr_reg[15:8] <= mem_wdata[15:8];
                        if (mem_wstrb[0]) disp_addr_reg[7:0] <= mem_wdata[7:0];
                        rdata_r <= disp_addr_reg;
                    end
                    3'd2: begin
                        if (mem_wstrb[3]) work_addr_reg[31:24] <= mem_wdata[31:24];
                        if (mem_wstrb[2]) work_addr_reg[24:16] <= mem_wdata[24:16];
                        if (mem_wstrb[1]) work_addr_reg[15:8] <= mem_wdata[15:8];
                        if (mem_wstrb[0]) work_addr_reg[7:0] <= mem_wdata[7:0];
                        rdata_r <= work_addr_reg;
                    end
                    3'd3: begin
                        if (mem_wstrb[3]) color_reg[31:24] <= mem_wdata[31:24];
                        if (mem_wstrb[2]) color_reg[24:16] <= mem_wdata[24:16];
                        if (mem_wstrb[1]) color_reg[15:8] <= mem_wdata[15:8];
                        if (mem_wstrb[0]) color_reg[7:0] <= mem_wdata[7:0];
                        rdata_r <= color_reg;
                    end
                    3'd4: begin
                        if (mem_wstrb[3]) x0y0_reg[31:24] <= mem_wdata[31:24];
                        if (mem_wstrb[2]) x0y0_reg[24:16] <= mem_wdata[24:16];
                        if (mem_wstrb[1]) x0y0_reg[15:8] <= mem_wdata[15:8];
                        if (mem_wstrb[0]) x0y0_reg[7:0] <= mem_wdata[7:0];
                        rdata_r <= x0y0_reg;
                    end
                    3'd5: begin
                        if (mem_wstrb[3]) x1y1_reg[31:24] <= mem_wdata[31:24];
                        if (mem_wstrb[2]) x1y1_reg[24:16] <= mem_wdata[24:16];
                        if (mem_wstrb[1]) x1y1_reg[15:8] <= mem_wdata[15:8];
                        if (mem_wstrb[0]) x1y1_reg[7:0] <= mem_wdata[7:0];
                        rdata_r <= x1y1_reg;
                    end
                    3'd6: begin
                        if (mem_wstrb[3]) size_reg[31:24] <= mem_wdata[31:24];
                        if (mem_wstrb[2]) size_reg[24:16] <= mem_wdata[24:16];
                        if (mem_wstrb[1]) size_reg[15:8] <= mem_wdata[15:8];
                        if (mem_wstrb[0]) size_reg[7:0] <= mem_wdata[7:0];
                        rdata_r <= size_reg;
                    end
                    default: rdata_r <= 32'h0;
                endcase
            end
        end
    end

    assign mem_ready = ready_r;
    assign mem_rdata = rdata_r;

endmodule
