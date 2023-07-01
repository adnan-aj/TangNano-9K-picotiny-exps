

#ifndef __HWDEFS_H__
#define __HWDEFS_H__

#include <stdint.h>

typedef struct {
	volatile uint32_t DATA;
	volatile uint32_t CLKDIV;
} PICOUART;

typedef struct {
	volatile uint32_t OUT;
	volatile uint32_t IN;
	volatile uint32_t OE;
} PICOGPIO;

typedef struct {
	union {
		volatile uint32_t REG;
		volatile uint16_t IOW;
		struct {
			volatile uint8_t IO;
			volatile uint8_t OE;
			volatile uint8_t CFG;
			volatile uint8_t EN;
		};
	};
} PICOQSPI;

#define QSPI0 ((PICOQSPI *)0x81000000)
#define GPIO0 ((PICOGPIO *)0x82000000)
#define UART0 ((PICOUART *)0x83000000)

#define QSPI_REG_CRM  0x00100000
#define QSPI_REG_DSPI 0x00400000

#define CLK_FREQ	  33000000
#define UART_CLK_FREQ 27000000
#define UART_BAUD	  115200

#define FLASHIO_ENTRY_ADDR ((void *)0x80000054)

#endif /* __HWDEFS_H__ */