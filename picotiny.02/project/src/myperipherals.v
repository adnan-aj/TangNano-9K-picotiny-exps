`timescale 1ns / 1ps

module MyPeripherals #(
    parameter OSC_CLK_HZ = 27000000,
    parameter BAUD = 115200
) (
    input osc_clk,
    input cpu_clk,
    input resetn,

    input mem_valid,
    input [31:0] mem_addr,
    input [31:0] mem_wdata,
    input [3:0] mem_wstrb,
    output mem_ready,
    output [31:0] mem_rdata
);
    reg ready_r;
    reg [31:0] rdata_r;
    reg [31:0] msec_reg;
    reg [31:0] spare_reg;

    localparam msec_div = (OSC_CLK_HZ / 1000);
    reg [15:0] msec_tick_counter;
    reg msec_ticked;
    always @(posedge osc_clk) begin
        if (!resetn) begin
            msec_tick_counter <= 0;
            msec_ticked <= 0;
        end else begin
            msec_tick_counter <= msec_tick_counter + 1'b1;
            if (msec_tick_counter == (msec_div - 1)) begin
                msec_tick_counter <= 0;
            end
            msec_ticked <= (msec_tick_counter > (msec_div / 2)) ? 1'b1 : 1'b0;
        end
    end

    reg [1:0] msec_ticked_sr;
    always @(posedge cpu_clk) begin
        if (!resetn) begin
            msec_reg <= 0;
            msec_ticked_sr <= 0;
        end else begin
            msec_ticked_sr <= {msec_ticked_sr[0], msec_ticked};
            if (msec_ticked_sr == 2'b01) begin
                msec_reg <= msec_reg + 1'b1;
            end
        end
    end


    always @(posedge cpu_clk) begin
        if (!resetn) begin
            ready_r   <= 1'b0;
            spare_reg <= 32'b0;
        end else begin
            ready_r <= 1'b0;
            if (mem_valid && !ready_r) begin
                ready_r <= 1'b1;
                case (mem_addr[4:2])
                    0: begin
                        // read-only register
                        rdata_r <= msec_reg;
                    end
                    1: begin
                        if (mem_wstrb[3]) spare_reg[31:24] <= mem_wdata[31:24];
                        if (mem_wstrb[2]) spare_reg[24:16] <= mem_wdata[24:16];
                        if (mem_wstrb[1]) spare_reg[15:8] <= mem_wdata[15:8];
                        if (mem_wstrb[0]) spare_reg[7:0] <= mem_wdata[7:0];
                        rdata_r <= spare_reg;
                    end
                    default: rdata_r <= 32'h0;
                endcase
            end
        end
    end

    assign mem_ready = ready_r;
    assign mem_rdata = rdata_r;

endmodule
