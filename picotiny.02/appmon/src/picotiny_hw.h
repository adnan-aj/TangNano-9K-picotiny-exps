#ifndef __PICOTINY_HW_H__
#define __PICOTINY_HW_H__

#include "hwdefs.h"

void cmd_set_crm(int on);
int	 cmd_get_crm();
void cmd_set_dspi(int on);
int	 cmd_get_dspi();
void cmd_read_flash_id();

int __io_putchar(int c);
int __io_getchar();
int putchar_raw(int c);
int getchar_timeout_us(int cycles);

#endif /* __PICOTINY_HW_H__ */