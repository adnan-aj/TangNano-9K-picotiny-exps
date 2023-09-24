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

    input clk_osc,
    input hclk_mem,
    input pll_lock,
    output init_calib,
    output mclk_out,
    input mem_s_valid,
    input [31:0] mem_s_addr,
    input [31:0] mem_s_wdata,
    input [3:0] mem_s_wstrb,
    output [31:0] mem_s_rdata,
    output mem_s_ready,

    output [1:0] O_psram_ck,
    output [1:0] O_psram_ck_n,
    inout [15:0] IO_psram_dq,
    inout [1:0] IO_psram_rwds,
    output [1:0] O_psram_cs_n,
    output [1:0] O_psram_reset_n
);

`define LCD_1024x600_7INCH_SIPEED
`ifdef LCD_1024x600_7INCH_SIPEED
    localparam LCD_WIDTH = 16'd1024;
    localparam LCD_HEIGHT = 16'd600;
    localparam H_FrontPorch = 16'd210;
    localparam H_PulseWidth = 16'd16;
    localparam H_BackPorch = 16'd182;
    localparam V_FrontPorch = 16'd45;
    localparam V_PulseWidth = 16'd5;
    localparam V_BackPorch = 16'd0;
    localparam VDMA_MAXBLKCNT = 8'd64;
    localparam VDMA_LINEADDR_STRIDE = 23'd2048;
`else // LCD_800x480_5INCH_SIPEED
    localparam LCD_WIDTH = 16'd800;
    localparam LCD_HEIGHT = 16'd480;
    localparam H_FrontPorch = 16'd0;
    localparam H_PulseWidth = 16'd256;
    localparam H_BackPorch = 16'd0;
    localparam V_FrontPorch = 16'd0; // 45 or 0
    localparam V_PulseWidth = 16'd45;
    localparam V_BackPorch = 16'd0; // 0 or 45
    localparam VDMA_MAXBLKCNT = 8'd50;
    localparam VDMA_LINEADDR_STRIDE = 23'd2048;
`endif

    reg [10:0] CounterX;
    reg [9:0] CounterY;
    wire [10:0] PixelCount = CounterX;
    wire [10:0] dma_raddr = CounterX;

    reg vga_HS, vga_VS, inDisplayArea;
    reg [4:0] Data_R;
    reg [5:0] Data_G;
    reg [4:0] Data_B;
    wire [15:0] dout_o;

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
        vga_HS <= (CounterX > (LCD_WIDTH + H_FrontPorch) &&
                  (CounterX < (LCD_WIDTH + H_FrontPorch + H_PulseWidth)));
        vga_VS <= (CounterY > (LCD_HEIGHT + V_FrontPorch) &&
                  (CounterY < (LCD_HEIGHT + V_FrontPorch + V_PulseWidth)));
    end

    always @(posedge pclk) begin
        inDisplayArea <= (CounterX > 0 && CounterX <= LCD_WIDTH) &&
                         (CounterY > 0 && CounterY <= LCD_HEIGHT);
        Data_R <= dout_o[15:11];
        Data_G <= dout_o[10:5];
        Data_B <= dout_o[4:0];
    end

    assign LCD_HSYNC = ~vga_HS;
    assign LCD_VSYNC = ~vga_VS;
    assign LCD_DE    = inDisplayArea;
    assign LCD_R     = Data_R;
    assign LCD_G     = Data_G;
    assign LCD_B     = Data_B;

    /*  to also start at line before zero because inDisplay starts at 1 */
    wire vdma_start = vga_HS && ((CounterY < LCD_HEIGHT) || CounterYmaxed);

    wire [31:0] gpu_ctrl;
    wire [22:0] disp_addr;
    wire [22:0] work_addr;
    wire [15:0] rgb565;
    wire [31:0] x0y0_point;
    wire [31:0] x1y1_point;
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
        .x1y1_point(x1y1_point),
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

    reg [1:0] gpu_cmd_sr;
    reg gpu_setbg_start, gpu_setbg_cont;
    reg gpu_setpt_start;
    reg gpu_frect_start, gpu_frect_cont;

    wire [15:0] x0_val = x0y0_point[15:0];
    wire [15:0] y0_val = x0y0_point[31:16];
    wire [15:0] x1_val = x1y1_point[15:0];
    wire [15:0] y1_val = x1y1_point[31:16];
    
    /* masks for line within a block of 16 pixels */
    wire [15:0] pixmask_on[0:15], pixmask_off[0:15];

    assign pixmask_on[0]  = 16'b1111_1111_1111_1111;
    assign pixmask_on[1]  = 16'b1111_1111_1111_1110;
    assign pixmask_on[2]  = 16'b1111_1111_1111_1100;
    assign pixmask_on[3]  = 16'b1111_1111_1111_1000;
    assign pixmask_on[4]  = 16'b1111_1111_1111_0000;
    assign pixmask_on[5]  = 16'b1111_1111_1110_0000;
    assign pixmask_on[6]  = 16'b1111_1111_1100_0000;
    assign pixmask_on[7]  = 16'b1111_1111_1000_0000;
    assign pixmask_on[8]  = 16'b1111_1111_0000_0000;
    assign pixmask_on[9]  = 16'b1111_1110_0000_0000;
    assign pixmask_on[10] = 16'b1111_1100_0000_0000;
    assign pixmask_on[11] = 16'b1111_1000_0000_0000;
    assign pixmask_on[12] = 16'b1111_0000_0000_0000;
    assign pixmask_on[13] = 16'b1110_0000_0000_0000;
    assign pixmask_on[14] = 16'b1100_0000_0000_0000;
    assign pixmask_on[15] = 16'b1000_0000_0000_0000;

    assign pixmask_off[0]  = 16'b0000_0000_0000_0001;
    assign pixmask_off[1]  = 16'b0000_0000_0000_0011;
    assign pixmask_off[2]  = 16'b0000_0000_0000_0111;
    assign pixmask_off[3]  = 16'b0000_0000_0000_1111;
    assign pixmask_off[4]  = 16'b0000_0000_0001_1111;
    assign pixmask_off[5]  = 16'b0000_0000_0011_1111;
    assign pixmask_off[6]  = 16'b0000_0000_0111_1111;
    assign pixmask_off[7]  = 16'b0000_0000_1111_1111;
    assign pixmask_off[8]  = 16'b0000_0001_1111_1111;
    assign pixmask_off[9]  = 16'b0000_0011_1111_1111;
    assign pixmask_off[10] = 16'b0000_0111_1111_1111;
    assign pixmask_off[11] = 16'b0000_1111_1111_1111;
    assign pixmask_off[12] = 16'b0001_1111_1111_1111;
    assign pixmask_off[13] = 16'b0011_1111_1111_1111;
    assign pixmask_off[14] = 16'b0111_1111_1111_1111;
    assign pixmask_off[15] = 16'b1111_1111_1111_1111;

    function [15:0] pixmask(input [3:0] startpix, endpix);
        begin
            pixmask = pixmask_on[startpix] & pixmask_off[endpix];
        end
    endfunction

    reg  [15:0] curr_x;
    reg  [15:0] curr_y;
    wire [22:0] curr_y_lineaddr = work_addr + curr_y * VDMA_LINEADDR_STRIDE;
    /* be careful: memaddr is (x_pixs << 1), but is also in 4-byte alignment */
    wire [22:0] curr_xy_blkaddr = (curr_y_lineaddr + ((curr_x << 1) & 16'b1111_1111_1110_0000)) >> 2;

    wire [ 3:0] curr_x0_bounded = ((curr_x >> 4) > (x0_val >> 4)) ? 0 : x0_val & 4'b1111;
    wire [ 3:0] curr_x1_bounded = ((curr_x >> 4) < (x1_val >> 4)) ? 4'b1111 : x1_val & 4'b1111;
    wire [15:0] ln = pixmask(curr_x0_bounded, curr_x1_bounded);

    wire [63:0] wdata_allpix_rgb565 = {rgb565, rgb565, rgb565, rgb565};
    // verilog_format: off
    /* pixel point mask */
    wire [15:0] pm = (1'b1 << x0_val[3:0]);
    wire [63:0] pt_pixelmask32 = ~{ pm[15],pm[14],pm[13],pm[12],pm[15],pm[14],pm[13],pm[12],
                                    pm[11],pm[10],pm[9], pm[8], pm[11],pm[10],pm[9], pm[8],
                                    pm[7], pm[6], pm[5], pm[4], pm[7], pm[6], pm[5], pm[4],
                                    pm[3], pm[2], pm[1], pm[0], pm[3], pm[2], pm[1], pm[0] };
    /* line within block masking */
    wire [63:0] ln_pixelmask32 = ~{ ln[15],ln[14],ln[13],ln[12],ln[15],ln[14],ln[13],ln[12],
                                    ln[11],ln[10],ln[9], ln[8], ln[11],ln[10],ln[9], ln[8],
                                    ln[7], ln[6], ln[5], ln[4], ln[7], ln[6], ln[5], ln[4],
                                    ln[3], ln[2], ln[1], ln[0], ln[3], ln[2], ln[1], ln[0] };

    assign gpu_is_busy = gpu_setbg_start | gpu_setbg_cont |
                         gpu_setpt_start |
                         gpu_frect_start | gpu_frect_cont;  
    // verilog_format: on


    always @(posedge mclk_out) begin
        if (!sys_resetn) begin
            state           <= 3'd0;
            cycle           <= 8'b0;
            cmd_en_i        <= 0;
            read_back       <= 0;
            completed       <= 0;
            vdma_waddr      <= 0;
            vdma_wdata      <= 0;
            vdma_wstrb      <= 0;
            vdma_waitinc    <= 0;
            vdma_wdata      <= 0;
            vdma_start_sr   <= 0;
            vdma_blkcnt     <= 0;
            vdma_lineidx    <= 0;
            gpu_cmd_sr      <= 0;
            gpu_setbg_start <= 0;
            gpu_setbg_cont  <= 0;
            gpu_setpt_start <= 0;
            gpu_frect_start <= 0;
            gpu_frect_cont  <= 0;
            curr_x          <= 0;
            curr_y          <= 0;
        end else begin
            vdma_start_sr = {vdma_start_sr[1:0], vdma_start};
            gpu_cmd_sr <= {gpu_cmd_sr[0], gpu_ctrl[0]};
            if (gpu_cmd_sr[1:0] == 2'b01) begin
                case (gpu_ctrl[4:1])
                    1: begin
                        gpu_setbg_start <= 1;
                        curr_x          <= 0;
                        curr_y          <= 0;
                    end
                    2: begin
                        gpu_setpt_start <= 1;
                        curr_x          <= x0_val;
                        curr_y          <= y0_val;
                    end
                    3: begin
                        gpu_frect_start <= 1;
                        curr_x          <= x0_val;
                        curr_y          <= y0_val;
                    end
                endcase
            end
            case (state)
                default: begin
                    cycle      <= 0;
                    completed  <= 0;
                    vdma_wstrb <= 0;

                    if (vdma_start_sr[2:1] == 2'b01) begin
                        if (CounterY < LCD_HEIGHT) begin
                            // i.e. 0 < CounterY < 600
                            state        <= 3;  // set to vdma_read_State
                            addr_i       <= {vdma_lineaddr[22:11], 6'b0, 3'b0};
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
                            state        <= 1;  // set to write_state
                            addr_i[20:0] <= {mem_s_addr[22:5], w_remap[mem_s_addr[4:2]]};
                            wrdata_i     <= mem_s_wdata;
                            data_mask_i  <= {2'b11, we3, we1, 2'b11, we2, we0};
                            cmd_i        <= 1;
                            cmd_en_i     <= 1;
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
                            gpu_setbg_cont  <= 1;
                        end
                        wrdata_i <= wdata_allpix_rgb565;
                        data_mask_i <= 8'h00;
                        addr_i <= curr_xy_blkaddr;
                        cmd_i <= 1;
                        cmd_en_i <= 1;
                    end else if (gpu_setpt_start) begin
                        state <= 5;
                        gpu_setpt_start <= 0;
                        wrdata_i <= wdata_allpix_rgb565;
                        data_mask_i <= pt_pixelmask32[7:0];
                        addr_i <= curr_xy_blkaddr;
                        cmd_i <= 1;
                        cmd_en_i <= 1;
                    end else if (gpu_frect_start || gpu_frect_cont) begin
                        state <= 6;
                        gpu_frect_start <= 0;
                        if (gpu_frect_start) begin
                            gpu_frect_cont <= 1;
                        end
                        wrdata_i <= wdata_allpix_rgb565;
                        data_mask_i	<= ln_pixelmask32[7:0];
                        addr_i <= curr_xy_blkaddr;
                        cmd_i <= 1;
                        cmd_en_i <= 1;
                    end 
                end
                1: begin  /* PSRAM write state */
                    cmd_en_i <= 0;
                    cycle    <= cycle + 1'b1;
                    case (cycle)
                        default: begin
                            // stop writing after the first 32-bit word
                            data_mask_i <= 8'hff;
                        end
                        13: begin
                            // IPUG 943 - Table 4-2, Tcmd is 14 when burst == 16
                            completed <= 1;
                            cycle     <= 0;
                            state     <= 0;
                        end
                    endcase
                end
                2: begin  /* PSRAM read state */
                    cmd_en_i <= 0;
                    if (rd_data_valid) begin
                        read_count <= read_count + 1'b1;
                        if ((read_count & READ_COUNT_TOP) == ((mem_s_addr >> 3) & READ_COUNT_TOP))begin
                            if (~mem_s_addr[2]) read_back[31:0] <= rd_data[31:0];
                            else read_back[31:0] <= rd_data[63:32];
                        end
                        if (read_count >= READ_COUNT_TOP) begin
                            completed <= 1;
                            state     <= 0;
                        end
                    end
                end
                3: begin  /* Video line PSRAM-to-linebuf vdma_read state */
                    cmd_en_i <= 0;
                    cycle    <= cycle + 1'b1;
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
                    cycle    <= cycle + 1'b1;
                    /* turn off gpu_setbg_cont when limits are reached, but can
                     * still continue on state 4 until end of block-write */
                    if (curr_x >= ((LCD_WIDTH - 1) & 16'b1111_1111_1111_0000) && curr_y >= (LCD_HEIGHT - 1)) begin
                        gpu_setbg_cont  <= 0;
                    end
                    case (cycle)
                         13: begin
                            cycle <= 0;
                            state <= 0;
                            if (curr_x < ((LCD_WIDTH - 1) & 16'b1111_1111_1111_0000))
                                curr_x <= curr_x + 16'd16;
                            else begin
                                curr_x <= 0;
                                curr_y <= curr_y + 1'b1;
                            end
                        end
                    endcase
                end
                5: begin
                    /* draw a point from x0y0_reg with color_reg
                     * this will serve as a test of (a) calculating lineaddr from Y0
                     * with multiplication-and-add to workaddr_reg (b) calculating
                     * of byte(?) address and mask for pixel x-axis from X0. */
                    cmd_en_i <= 0;
                    cycle    <= cycle + 1'b1;
                    case (cycle)
                        0: data_mask_i <= pt_pixelmask32[15:8];
                        1: data_mask_i <= pt_pixelmask32[23:16];
                        2: data_mask_i <= pt_pixelmask32[31:24];
                        default: data_mask_i <= 8'hff;
                        13: begin
                            cycle           <= 0;
                            state           <= 0;
                            gpu_setpt_start <= 0;
                        end
                    endcase
                end
                6: begin
                    /* draw a filled rect from x0y0_reg to x1y1_reg with color_reg */
                    cmd_en_i <= 0;
                    cycle    <= cycle + 1'b1;
                    if (curr_x >= (x1_val & 16'b1111_1111_1111_0000) && curr_y >= (y1_val)) begin
                        gpu_frect_cont  <= 0;
                    end
                    case (cycle)
                        0: data_mask_i <= ln_pixelmask32[15:8];
                        1: data_mask_i <= ln_pixelmask32[23:16];
                        2: data_mask_i <= ln_pixelmask32[31:24];
                        default:
                            data_mask_i <= 8'hff;
                        13: begin
                            cycle <= 0;
                            state <= 0;
                            if (curr_x < (x1_val & 16'b1111_1111_1111_0000))
                                curr_x <= curr_x + 16'd16;
                            else begin
                                curr_x <= x0_val;
                                curr_y <= curr_y + 1'b1;
                            end
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

endmodule /* PSRAM_FRAMEBUFFER_LCD */

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
    output [31:0] x1y1_point,
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
    assign disp_addr  = disp_addr_reg[22:0];
    assign work_addr  = work_addr_reg[22:0];
    assign x0y0_point = x0y0_reg;
    assign x1y1_point = x1y1_reg;

    wire r0, g0, b0;
    assign r0     = color_reg[19] | color_reg[18] | color_reg[17] | color_reg[16];
    assign g0     = color_reg[10] | color_reg[9] | color_reg[8];
    assign b0     = color_reg[3] | color_reg[2] | color_reg[1] | color_reg[0];
    assign rgb565 = {color_reg[23:20], r0, color_reg[15:11], g0, color_reg[7:4], b0};

    always @(posedge cpu_clk) begin
        if (!resetn) begin
            ready_r       <= 1'b0;
            ctrl_stat_reg <= 32'b0;
            disp_addr_reg <= 32'b0;
            work_addr_reg <= 32'b0;
            color_reg     <= 32'b0;
            x0y0_reg      <= 32'b0;
            x1y1_reg      <= 32'b0;
            size_reg      <= 32'b0;
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

endmodule /* FB_Registers */
