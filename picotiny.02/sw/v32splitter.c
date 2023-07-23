#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>

static char *trimwhitespace(char *str)
{
	char *end;
	// Trim leading space
	while (isspace((unsigned char)*str))
		str++;
	if (*str == 0) // All spaces?
		return str;
	// Trim trailing space
	end = str + strlen(str) - 1;
	while (end > str && isspace((unsigned char)*end))
		end--;
	// Write new null terminator character
	end[1] = '\0';
	return str;
}

void printfile_prologue(FILE *outfp, int bank);
void printfile_epilogue(FILE *outfp, int bank);

int main(int argc, char *argv[])
{
	uint32_t u32ram[2048];
	char	 outbasename[PATH_MAX];
	FILE	*outfp;

	printf("ObjDump V32 2kWord file-to-gowin-verilog 2kx8 ROM Splitter\n");
	strcpy(outbasename, "myboot_2kx8");

	if (argc < 2) {
		printf("Usage: %s <v32 filename> [outfile_basename]\n", argv[0]);
		return -1;
	}
	if (argc > 3) {
		strcpy(outbasename, argv[2]);
	}

	memset(u32ram, 0, sizeof(u32ram));

	FILE *infp = fopen(argv[1], "r");
	int	  lines = 0, lines_with_content = 0;
	char  buf[80];
	errno = 0;
	while (!feof(infp) && errno == 0) {
		fgets(buf, sizeof(buf), infp);
		lines++;
		char *lp = trimwhitespace(buf);
		printf("Reading line %3d: '%s'\n", lines, lp);
		if (strlen(lp) >= 8 && isxdigit(*lp)) { // TODO: something wrong here!!!
			uint32_t val = strtoul(buf, NULL, 16);
			if (errno == 0) {
				u32ram[lines_with_content++] = val;
			}
			else {
				printf("err = %d\n", errno);
			}
		}
	}
	fclose(infp);
	printf("Num lines read = %d\n", lines);
	printf("Num lines with content = %d\n", lines_with_content);
	for (int i = 0; i < 35; i++) {
		printf("%2d: 0x%08x\n", i, u32ram[i]);
	}
	printf("\n");

	// defparam sp_inst_0.INIT_RAM_00 = 256'h80C68007800C80819007070000F0052008850505058181110000000000000000;
	// defparam sp_inst_0.INIT_RAM_00 = 256'h932393b713136323a32313b76fef6f1323639397131713939713131313131313;

	outfp = stdout;
	if (errno == 0) {
		for (int bank = 0; bank < 4; bank++) {
			char ofname[PATH_MAX];
			sprintf(ofname, "%s_%d.v", outbasename, bank);
			outfp = fopen(ofname, "w");
			if (outfp == NULL) {
				printf("%s: file %s write open error\n", argv[0], ofname);
				exit(1);
			}
			printfile_prologue(outfp, bank);
			int maxaddr = 2048;
			for (int lineaddr = 0; lineaddr < maxaddr; lineaddr += 32) {
				fprintf(outfp, "defparam sp_inst_0.INIT_RAM_%02X = 256'h", lineaddr / 32);
				for (int ad = 0; ad < 32; ad++) {
					uint32_t u32val = u32ram[lineaddr + 31 - ad];
					fprintf(outfp, "%02x", (u32val >> (bank * 8)) & 0xFF); // MASK & CHISFT DOWN AGAIN
				}
				fprintf(outfp, ";\n");
			}
			printfile_epilogue(outfp, bank);
			if (outfp != stdout)
				fclose(outfp);
		}
	}

	return 0;
}

void printfile_epilogue(FILE *outfp, int bank)
{
	if (outfp == NULL)
		outfp = stdout;
	fprintf(outfp, "\nendmodule //bootram_2kx8_%d\n\n", bank);
}

void printfile_prologue(FILE *outfp, int bank)
{
	if (outfp == NULL)
		outfp = stdout;
	char time_create[] = "Thu Jan 20 13:31:52 2022";
	fprintf(outfp, "//Copyright (C)2014-2021 Gowin Semiconductor Corporation.\n"
				   "//All rights reserved.\n"
				   "//File Title: IP file\n"
				   "//GOWIN Version: V1.9.8\n"
				   "//Part Number: GW1N-LV9QN88C6/I5\n"
				   "//Device: GW1N-9\n"
				   "//Created Time: %s\n\n",
			time_create);
	fprintf(outfp, "module bootram_2kx8_%d (dout, clk, oce, ce, reset, wre, ad, din);\n\n"
				   "output [7:0] dout;\n"
				   "input clk;\n"
				   "input oce;\n"
				   "input ce;\n"
				   "input reset;\n"
				   "input wre;\n"
				   "input [10:0] ad;\n"
				   "input [7:0] din;\n\n"
				   "wire [23:0] sp_inst_0_dout_w;\n"
				   "wire gw_gnd;\n\n"
				   "assign gw_gnd = 1'b0;\n\n"
				   "SP sp_inst_0 (\n"
				   "	.DO({sp_inst_0_dout_w[23:0],dout[7:0]}),\n"
				   "	.CLK(clk),\n"
				   "	.OCE(oce),\n"
				   "	.CE(ce),\n"
				   "	.RESET(reset),\n"
				   "	.WRE(wre),\n"
				   "	.BLKSEL({gw_gnd,gw_gnd,gw_gnd}),\n"
				   "	.AD({ad[10:0],gw_gnd,gw_gnd,gw_gnd}),\n"
				   "	.DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,"
				   "gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,"
				   "gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,"
				   "din[7:0]})\n"
				   ");\n\n",
			bank);
	fprintf(outfp, "defparam sp_inst_0.READ_MODE = 1'b0;\n"
				   "defparam sp_inst_0.WRITE_MODE = 2'b00;\n"
				   "defparam sp_inst_0.BIT_WIDTH = 8;\n"
				   "defparam sp_inst_0.BLK_SEL = 3'b000;\n"
				   "defparam sp_inst_0.RESET_MODE = \"SYNC\";\n");
}