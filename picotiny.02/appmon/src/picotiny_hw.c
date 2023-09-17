#include "hwdefs.h"
#include "picotiny_hw.h"

void cmd_set_crm(int on)
{
	if (on) {
		QSPI0->REG |= QSPI_REG_CRM;
	}
	else {
		QSPI0->REG &= ~QSPI_REG_CRM;
	}
}

int cmd_get_crm()
{
	return QSPI0->REG & QSPI_REG_CRM;
}

void cmd_set_dspi(int on)
{
	if (on) {
		QSPI0->REG |= QSPI_REG_DSPI;
	}
	else {
		QSPI0->REG &= ~QSPI_REG_DSPI;
	}
}

int cmd_get_dspi()
{
	return QSPI0->REG & QSPI_REG_DSPI;
}

#define PUTCHAR_DELAY_CNT 1

int __io_putchar(int c)
{
	if (c == '\n') {
		UART0->DATA = '\r';
	}
	UART0->DATA = c;
	return c;
}

int __io_getchar()
{
	int c;
	do {
		c = UART0->DATA;
	} while (c == -1);
	return c;
}

int putchar_raw(int c)
{
	UART0->DATA = c;
	return c;
}

int getchar_timeout_us(int cycles)
{
	int		 c = -1;
	uint32_t cycles_begin, cycles_now;
	__asm__ volatile("rdcycle %0"
					 : "=r"(cycles_begin));
	do {
		c = UART0->DATA;
		if (c >= 0)
			return c;
		__asm__ volatile("rdcycle %0"
						 : "=r"(cycles_now));
	} while (cycles_now - cycles_begin < cycles);
	return -1;
}
