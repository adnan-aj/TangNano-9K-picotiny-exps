`timescale 1ns / 1ps

module picotiny (
    input clk_osc27,
    input resetn,

    output flash_clk,
    output flash_csb,
    inout  flash_mosi,
    inout  flash_miso,

    input ser_rx,
    output ser_tx,
    inout [6:0] gpio,

    output ser_pulse,
    //output clk_cpu,
    output LCD_CLK,
    output LCD_HYNC,
    output LCD_SYNC,
    output LCD_DEN,
    output [4:0] LCD_R,
    output [5:0] LCD_G,
    output [4:0] LCD_B,

    output [CS_WIDTH-1:0] O_psram_ck,  // These ports are needed, or the PSRAM IP will not compile
    output [CS_WIDTH-1:0] O_psram_ck_n,
    inout [CS_WIDTH-1:0] IO_psram_rwds,
    inout [DQ_WIDTH-1:0] IO_psram_dq,
    output [CS_WIDTH-1:0] O_psram_reset_n,
    output [CS_WIDTH-1:0] O_psram_cs_n
);

    localparam DQ_WIDTH = 16;
    localparam CS_WIDTH = 2;


    wire sys_resetn;

    wire mem_valid;
    wire mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wstrb;
    wire [31:0] mem_rdata;

    wire spimemxip_valid;
    wire spimemxip_ready;
    wire [31:0] spimemxip_addr;
    wire [31:0] spimemxip_wdata;
    wire [3:0] spimemxip_wstrb;
    wire [31:0] spimemxip_rdata;

    wire sram_valid;
    wire sram_ready;
    wire [31:0] sram_addr;
    wire [31:0] sram_wdata;
    wire [3:0] sram_wstrb;
    wire [31:0] sram_rdata;

    wire picop_valid;
    wire picop_ready;
    wire [31:0] picop_addr;
    wire [31:0] picop_wdata;
    wire [3:0] picop_wstrb;
    wire [31:0] picop_rdata;

    wire wbp_valid;
    wire wbp_ready;
    wire [31:0] wbp_addr;
    wire [31:0] wbp_wdata;
    wire [3:0] wbp_wstrb;
    wire [31:0] wbp_rdata;

    wire spimemcfg_valid;
    wire spimemcfg_ready;
    wire [31:0] spimemcfg_addr;
    wire [31:0] spimemcfg_wdata;
    wire [3:0] spimemcfg_wstrb;
    wire [31:0] spimemcfg_rdata;

    wire brom_valid;
    wire brom_ready;
    wire [31:0] brom_addr;
    wire [31:0] brom_wdata;
    wire [3:0] brom_wstrb;
    wire [31:0] brom_rdata;

    wire gpio_valid;
    wire gpio_ready;
    wire [31:0] gpio_addr;
    wire [31:0] gpio_wdata;
    wire [3:0] gpio_wstrb;
    wire [31:0] gpio_rdata;

    wire uart_valid;
    wire uart_ready;
    wire [31:0] uart_addr;
    wire [31:0] uart_wdata;
    wire [3:0] uart_wstrb;
    wire [31:0] uart_rdata;


    wire pll_lock;
    wire clk_out_o;
    wire init_calib_o;
    wire clk_mem;
    wire clk_cpu;

    Gowin_rPLL_132 u_rpll_132 (
        .clkin (clk_osc27),
        .clkout(clk_mem),
        .lock  (pll_lock)
    );

    Gowin_CLKDIV2 u_clkdiv2 (
        .hclkin(clk_out_o),
        .resetn(init_calib_o),
        .clkout(clk_cpu)
    );


    Reset_Sync u_Reset_Sync (
        .clk(clk_cpu),
        .ext_reset(resetn & pll_lock),
        .resetn(sys_resetn)
    );

    picorv32 #(
        .PROGADDR_RESET(32'h8000_0000)
    ) u_picorv32 (
        .clk(clk_cpu),
        .resetn(sys_resetn),
        .trap(),
        .mem_valid(mem_valid),
        .mem_instr(),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .irq(32'b0),
        .eoi()
    );

    PicoMem_SRAM_8KB u_PicoMem_SRAM_8KB_7 (
        .clk(clk_cpu),
        .resetn(sys_resetn),
        .mem_s_valid(sram_valid),
        .mem_s_ready(sram_ready),
        .mem_s_addr(sram_addr),
        .mem_s_wdata(sram_wdata),
        .mem_s_wstrb(sram_wstrb),
        .mem_s_rdata(sram_rdata)
    );

    // S0 0x0000_0000 -> SPI Flash XIP
    // S1 0x4000_0000 -> SRAM's
    // S2 0x8000_0000 -> PicoPeriph
    // S3 0xC000_0000 -> Wishbone
    PicoMem_Mux_1_4 u_PicoMem_Mux_1_4_8 (
        .picom_valid(mem_valid),
        .picom_ready(mem_ready),
        .picom_addr (mem_addr),
        .picom_wdata(mem_wdata),
        .picom_wstrb(mem_wstrb),
        .picom_rdata(mem_rdata),

        .picos0_valid(spimemxip_valid),
        .picos0_ready(spimemxip_ready),
        .picos0_addr (spimemxip_addr),
        .picos0_wdata(spimemxip_wdata),
        .picos0_wstrb(spimemxip_wstrb),
        .picos0_rdata(spimemxip_rdata),

        .picos1_valid(sram_valid),
        .picos1_ready(sram_ready),
        .picos1_addr (sram_addr),
        .picos1_wdata(sram_wdata),
        .picos1_wstrb(sram_wstrb),
        .picos1_rdata(sram_rdata),

        .picos2_valid(picop_valid),
        .picos2_ready(picop_ready),
        .picos2_addr (picop_addr),
        .picos2_wdata(picop_wdata),
        .picos2_wstrb(picop_wstrb),
        .picos2_rdata(picop_rdata),

        .picos3_valid(wbp_valid),
        .picos3_ready(wbp_ready),
        .picos3_addr (wbp_addr),
        .picos3_wdata(wbp_wdata),
        .picos3_wstrb(wbp_wstrb),
        .picos3_rdata(wbp_rdata)
    );

    // S0 0x8000_0000 -> BOOTROM
    // S1 0x8100_0000 -> SPI Flash
    // S2 0x8200_0000 -> GPIO
    // S3 0x8300_0000 -> UART
    PicoMem_Mux_1_4 #(
        .PICOS0_ADDR_BASE(32'h8000_0000),
        .PICOS0_ADDR_MASK(32'h0F00_0000),
        .PICOS1_ADDR_BASE(32'h8100_0000),
        .PICOS1_ADDR_MASK(32'h0F00_0000),
        .PICOS2_ADDR_BASE(32'h8200_0000),
        .PICOS2_ADDR_MASK(32'h0F00_0000),
        .PICOS3_ADDR_BASE(32'h8300_0000),
        .PICOS3_ADDR_MASK(32'h0F00_0000)
    ) u_PicoMem_Mux_1_4_picop (
        .picom_valid(picop_valid),
        .picom_ready(picop_ready),
        .picom_addr (picop_addr),
        .picom_wdata(picop_wdata),
        .picom_wstrb(picop_wstrb),
        .picom_rdata(picop_rdata),

        .picos0_valid(brom_valid),
        .picos0_ready(brom_ready),
        .picos0_addr (brom_addr),
        .picos0_wdata(brom_wdata),
        .picos0_wstrb(brom_wstrb),
        .picos0_rdata(brom_rdata),

        .picos1_valid(spimemcfg_valid),
        .picos1_ready(spimemcfg_ready),
        .picos1_addr (spimemcfg_addr),
        .picos1_wdata(spimemcfg_wdata),
        .picos1_wstrb(spimemcfg_wstrb),
        .picos1_rdata(spimemcfg_rdata),

        .picos2_valid(gpio_valid),
        .picos2_ready(gpio_ready),
        .picos2_addr (gpio_addr),
        .picos2_wdata(gpio_wdata),
        .picos2_wstrb(gpio_wstrb),
        .picos2_rdata(gpio_rdata),

        .picos3_valid(uart_valid),
        .picos3_ready(uart_ready),
        .picos3_addr (uart_addr),
        .picos3_wdata(uart_wdata),
        .picos3_wstrb(uart_wstrb),
        .picos3_rdata(uart_rdata)
    );

    PicoMem_SPI_Flash u_PicoMem_SPI_Flash_18 (
        .clk   (clk_cpu),
        .resetn(sys_resetn),

        .flash_csb (flash_csb),
        .flash_clk (flash_clk),
        .flash_mosi(flash_mosi),
        .flash_miso(flash_miso),

        .flash_mem_valid(spimemxip_valid),
        .flash_mem_ready(spimemxip_ready),
        .flash_mem_addr (spimemxip_addr),
        .flash_mem_wdata(spimemxip_wdata),
        .flash_mem_wstrb(spimemxip_wstrb),
        .flash_mem_rdata(spimemxip_rdata),

        .flash_cfg_valid(spimemcfg_valid),
        .flash_cfg_ready(spimemcfg_ready),
        .flash_cfg_addr (spimemcfg_addr),
        .flash_cfg_wdata(spimemcfg_wdata),
        .flash_cfg_wstrb(spimemcfg_wstrb),
        .flash_cfg_rdata(spimemcfg_rdata)
    );

    PicoMem_BOOT_SRAM_8KB u_boot_sram (
        .clk(clk_cpu),
        .resetn(sys_resetn),
        .mem_s_valid(brom_valid),
        .mem_s_ready(brom_ready),
        .mem_s_addr(brom_addr),
        .mem_s_wdata(brom_wdata),
        .mem_s_wstrb(brom_wstrb),
        .mem_s_rdata(brom_rdata)
    );

    PicoMem_GPIO u_PicoMem_GPIO (
        .clk(clk_cpu),
        .resetn(sys_resetn),
        .io(gpio),
        .busin_valid(gpio_valid),
        .busin_ready(gpio_ready),
        .busin_addr(gpio_addr),
        .busin_wdata(gpio_wdata),
        .busin_wstrb(gpio_wstrb),
        .busin_rdata(gpio_rdata)
    );

    PicoMem_115200_UART_27M u_PicoMem_UART (
        .cpu_clk(clk_cpu),
        .baudgen_clk(clk_osc27),
        .resetn(sys_resetn),
        .mem_s_valid(uart_valid),
        .mem_s_ready(uart_ready),
        .mem_s_addr(uart_addr),
        .mem_s_wdata(uart_wdata),
        .mem_s_wstrb(uart_wstrb),
        .mem_s_rdata(uart_rdata),
        .ser_rx(ser_rx),
        .ser_tx(ser_tx),
        .uart_debug_pulse(ser_pulse)
    );



    // WBP_S0 0x8000_0000 -> PSRAM
    // WBP_S1 0x8100_0000 -> Line Buf
    // WBP_S2 0x8200_0000 -> Spare
    // WBP_S3 0x8300_0000 -> Spare
    wire psram_valid;
    wire psram_ready;
    wire [31:0] psram_addr;
    wire [31:0] psram_rdata;
    wire [31:0] psram_wdata;
    wire [3:0] psram_wstrb;
    wire fbreg_valid;
    wire fbreg_ready;
    wire [31:0] fbreg_addr;
    wire [31:0] fbreg_rdata;
    wire [31:0] fbreg_wdata;
    wire [3:0] fbreg_wstrb;
    wire wbp2_valid;
    wire wbp2_ready;
    wire [31:0] wbp2_addr;
    wire [31:0] wbp2_rdata;
    wire [31:0] wbp2_wdata;
    wire [3:0] wbp2_wstrb;
    wire wbp3_valid;
    wire wbp3_ready;
    wire [31:0] wbp3_addr;
    wire [31:0] wbp3_rdata;
    wire [31:0] wbp3_wdata;
    wire [3:0] wbp3_wstrb;

    // Spare WBP Address Space decoding
    PicoMem_Mux_1_4 #(
        .PICOS0_ADDR_BASE(32'hC000_0000),
        .PICOS0_ADDR_MASK(32'h0F00_0000),
        .PICOS1_ADDR_BASE(32'hC100_0000),
        .PICOS1_ADDR_MASK(32'h0F00_0000),
        .PICOS2_ADDR_BASE(32'hC200_0000),
        .PICOS2_ADDR_MASK(32'h0F00_0000),
        .PICOS3_ADDR_BASE(32'hC300_0000),
        .PICOS3_ADDR_MASK(32'h0F00_0000)
    ) u_PicoMem_Mux_1_4_wbp (
        .picom_valid(wbp_valid),
        .picom_ready(wbp_ready),
        .picom_addr (wbp_addr),
        .picom_wdata(wbp_wdata),
        .picom_wstrb(wbp_wstrb),
        .picom_rdata(wbp_rdata),

        .picos0_valid(psram_valid),
        .picos0_ready(psram_ready),
        .picos0_addr (psram_addr),
        .picos0_wdata(psram_wdata),
        .picos0_wstrb(psram_wstrb),
        .picos0_rdata(psram_rdata),

        .picos1_valid(fbreg_valid),
        .picos1_ready(fbreg_ready),
        .picos1_addr (fbreg_addr),
        .picos1_wdata(fbreg_wdata),
        .picos1_wstrb(fbreg_wstrb),
        .picos1_rdata(fbreg_rdata),

        .picos2_valid(wbp2_valid),
        .picos2_ready(wbp2_ready),
        .picos2_addr (wbp2_addr),
        .picos2_wdata(wbp2_wdata),
        .picos2_wstrb(wbp2_wstrb),
        .picos2_rdata(wbp2_rdata),

        .picos3_valid(wbp3_valid),
        .picos3_ready(wbp3_ready),
        .picos3_addr (wbp3_addr),
        .picos3_wdata(wbp3_wdata),
        .picos3_wstrb(wbp3_wstrb),
        .picos3_rdata(wbp3_rdata)
    );

    assign wbp2_ready = 1'b1;
    assign wbp2_rdata = 32'hEFBEADDE; //DEADBEEF
    assign wbp3_ready = 1'b1;
    assign wbp3_rdata = 32'h0FB00DD0; //D00DB00F

    assign LCD_CLK = clk_cpu;
    PSRAM_FRAMEBUFFER_LCD D1 (
        .clk   (clk_cpu),
        .resetn(resetn),
        .pclk   (clk_cpu),

        .reg_valid(fbreg_valid),
        .reg_ready(fbreg_ready),
        .reg_addr (fbreg_addr),
        .reg_wdata(fbreg_wdata),
        .reg_wstrb(fbreg_wstrb),
        .reg_rdata(fbreg_rdata),

        .LCD_DE   (LCD_DEN),
        .LCD_HSYNC(LCD_HYNC),
        .LCD_VSYNC(LCD_SYNC),
        .LCD_B    (LCD_B),
        .LCD_G    (LCD_G),
        .LCD_R    (LCD_R),

        .clk_osc(clk_osc27),
        .hclk_mem(clk_mem),
        .pll_lock(pll_lock),
        .init_calib(init_calib_o),
        .mclk_out(clk_out_o),

        .mem_s_valid(psram_valid),
        .mem_s_ready(psram_ready),
        .mem_s_addr (psram_addr),
        .mem_s_wdata(psram_wdata),
        .mem_s_wstrb(psram_wstrb),
        .mem_s_rdata(psram_rdata),

        .O_psram_ck(O_psram_ck),
        .O_psram_ck_n(O_psram_ck_n),
        .IO_psram_dq(IO_psram_dq),
        .IO_psram_rwds(IO_psram_rwds),
        .O_psram_cs_n(O_psram_cs_n),
        .O_psram_reset_n(O_psram_reset_n)
    );

endmodule
