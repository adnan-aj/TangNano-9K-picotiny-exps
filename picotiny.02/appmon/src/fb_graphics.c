#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <stdlib.h>

#include "picotiny_hw.h"
#include "cli.h"
#include "sysutils.h"
#include "fb_graphics.h"

// uint32_t fgcolor_argb = 0xffffffff;

// clang-format off
//https://www.rapidtables.com/web/color/RGB_Color.html#RGB%20color%20table
const KEY_UINT32_PAIR colornames[] = {
	{"black",	0x000000},
	{"white",	0xFFFFFF},
	{"red",		0xFF0000},
	{"lime",	0x00FF00},
	{"blue",	0x0000FF},
	{"yellow",	0xFFFF00},
	{"cyan",	0x00FFFF},
	{"magenta",	0xFF00FF},
	{"silver",	0xC0C0C0},
	{"gray",	0x808080},
	{"maroon",	0x800000},
	{"olive",	0x808000},
	{"green",	0x008000},
	{"purple",	0x800080},
	{"teal",	0x008080},
	{"navy",	0x000080},
	{NULL, 0x0 }
};
// clang-format on
const char *colorname(uint32_t argb)
{
	KEY_UINT32_PAIR const *p = colornames;
	for (; p->key != NULL; p++) {
		if (p->value == (argb & 0xFFFFFF))
			return p->key;
	}
	return NULL;
}

int str2argb32(const char *color_str, uint32_t *argb32)
{
	bool ishexnum = true;
	bool found = false;
	/* test all chars of arg if it is hexnum */
	for (char *p = (char *)color_str; *p; p++)
		if (!isxdigit(*p))
			ishexnum = false;

	if (ishexnum) {
		*argb32 = strtol(color_str, NULL, 16);
	}
	else {
		for (int i = 0; colornames[i].key; i++) {
			if (strcasecmp(colornames[i].key, color_str) == 0) {
				*argb32 = colornames[i].value;
				found = true;
				break;
			}
		}
		if (!found) {
			return -1;
		}
	}
	return 0;
}

int plot_point(int x, int y, uint32_t argb)
{
	if (x < 0 || x > LCD_WIDTH || y < 0 || y > LCD_HEIGHT)
		return -1;

	uint32_t point_addr = ((y * LCD_WIDTH) + x) * LCD_PIXELBYTES + LCD_FBADDR;
	uint16_t rgb16 = ((argb >> 8) & LCD_RED) |
					 ((argb >> 5) & LCD_GREEN) |
					 ((argb >> 3) & LCD_BLUE);
	// printf("setting address 0x%08x with 0x%04X\n", point_addr, rgb16);
	*(uint16_t *)point_addr = rgb16;
	return 0;
}

int plot_line(int x0, int y0, int x1, int y1, uint32_t argb)
{
	// https://gist.github.com/bert/1085538
	// clang-format off
	int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
	int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
	int err = dx + dy, e2; /* error value e_xy */
	for (;;) { /* loop */
		plot_point(x0, y0, argb);
		if (x0 == x1 && y0 == y1) break;
		e2 = 2 * err;
		if (e2 >= dy) { err += dy;	x0 += sx; } /* e_xy+e_x > 0 */
		if (e2 <= dx) {	err += dx;	y0 += sy; } /* e_xy+e_y < 0 */
	}
	// clang-format on
	return 0;
}

int plot_circle(int xm, int ym, int r, uint32_t argb)
{
	// https://gist.github.com/bert/1085538
	// clang-format off
	int x = -r, y = 0, err = 2 - 2 * r; /* II. Quadrant */
	do {
		plot_point(xm - x, ym + y, argb); /*   I. Quadrant */
		plot_point(xm - y, ym - x, argb); /*  II. Quadrant */
		plot_point(xm + x, ym - y, argb); /* III. Quadrant */
		plot_point(xm + y, ym + x, argb); /*  IV. Quadrant */
		r = err;
		if (r > x)  err += ++x * 2 + 1; /* e_xy+e_x > 0 */
		if (r <= y) err += ++y * 2 + 1; /* e_xy+e_y < 0 */
	} while (x < 0);
	// clang-format on
	return 0;
}
