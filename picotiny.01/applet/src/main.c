#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#include "hwdefs.h"
#include "picotiny_hw.h"
#include "cli.h"

void (*spi_flashio)(uint8_t *pdata, int length, int wren) = FLASHIO_ENTRY_ADDR;

void cmd_read_flash_id()
{
	int pre_dspi = cmd_get_dspi();

	cmd_set_dspi(0);

	uint8_t buffer[4] = {0x9F, /* zeros */};
	spi_flashio(buffer, 4, 0);

	for (int i = 1; i <= 3; i++) {
		// putchar(' ');
		// print_hex(buffer[i], 2);
		printf("0x%02x ", buffer[i]);
	}
	printf("\n");

	cmd_set_dspi(pre_dspi);
}

uint32_t cmd_benchmark(bool verbose, uint32_t *instns_p)
{
	uint8_t	  data[256];
	uint32_t *words = (void *)data;

	uint32_t x32 = 314159265;

	uint32_t cycles_begin, cycles_end;
	uint32_t instns_begin, instns_end;
	__asm__ volatile("rdcycle %0"
					 : "=r"(cycles_begin));
	__asm__ volatile("rdinstret %0"
					 : "=r"(instns_begin));

	for (int i = 0; i < 20; i++) {
		for (int k = 0; k < 256; k++) {
			x32 ^= x32 << 13;
			x32 ^= x32 >> 17;
			x32 ^= x32 << 5;
			data[k] = x32;
		}

		for (int k = 0, p = 0; k < 256; k++) {
			if (data[k])
				data[p++] = k;
		}

		for (int k = 0, p = 0; k < 64; k++) {
			x32 = x32 ^ words[k];
		}
	}

	__asm__ volatile("rdcycle %0"
					 : "=r"(cycles_end));
	__asm__ volatile("rdinstret %0"
					 : "=r"(instns_end));

	if (verbose) {
		int cycles = cycles_end - cycles_begin;
		printf("Cycles: 0x%08x %d\n", cycles, cycles);

		int instns = instns_end - instns_begin;
		printf("Instns: 0x%08x %d\n", instns, instns);

		printf("Chksum: 0x%08x\n\n", x32);
	}

	if (instns_p)
		*instns_p = instns_end - instns_begin;

	return cycles_end - cycles_begin;
}

char appname[64] = "My first 27MHz-UART pmon";

void main()
{
	volatile int i;

	// UART0->CLKDIV = CLK_FREQ / UART_BAUD - 2;
	GPIO0->OE = 0x3F;
	GPIO0->OUT = 0x3F;
	cmd_set_crm(1);
	cmd_set_dspi(1);

	GPIO0->OUT = 0x1F;
	for (i = 0; i < 10000; i++)
		;
	GPIO0->OUT = 0x3F;

	printf("\n\nHello, world!\n");
	GPIO0->OUT = 0x3F ^ 0x01;

	printf("A number %d\n", 12345);
	GPIO0->OUT = 0x3F ^ 0x02;

	printf("2 numbers %d %d\n", 12345, 1 + 2 + 3 + 4 + 5 + 6);
	GPIO0->OUT = 0x3F ^ 0x04;

	printf("A B C\n");
	GPIO0->OUT = 0x3F ^ 0x08;

	printf("A string %s\n\n", appname);
	GPIO0->OUT = 0x3F ^ 0x10;
	for (i = 0; i < 10000; i++)
		;

	GPIO0->OUT = 0x3F ^ 0x20;
	printf("  ____  _          ____         ____\n");
	printf(" |  _ \\(_) ___ ___/ ___|  ___  / ___|\n");
	printf(" | |_) | |/ __/ _ \\___ \\ / _ \\| |\n");
	printf(" |  __/| | (_| (_) |__) | (_) | |___\n");
	printf(" |_|   |_|\\___\\___/____/ \\___/ \\____|\n\n");
	printf("    On Lichee Tang Nano-9K REBUILT\n\n");
	GPIO0->OUT = 0x3F;

	cmd_benchmark(1, 0);
	for (i = 0; i < 10000; i++)
		;
	GPIO0->OUT = 0x00;
	for (i = 0; i < 10000; i++)
		;
	GPIO0->OUT = 0x3F;
	for (i = 0; i < 10000; i++)
		;

	while (1) {
		do_nonblock_cli();
	}
}

void irqCallback()
{
}

// Single SPI cycles: 17781487
// DSPI mode cycles:   9105871
// DSPI+CRM cycles:    8919919