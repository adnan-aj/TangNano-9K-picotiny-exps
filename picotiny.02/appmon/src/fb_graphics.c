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
#include "allFonts.h"

// uint32_t fgcolor_argb = 0xffffffff;
int init_gui()
{
	fb_setcolor(0xFFFFFF);
	return 0;
}

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

	/* test all chars of arg if it is hexnum */
	for (char *p = (char *)color_str; *p; p++)
		if (!isxdigit(*p))
			ishexnum = false;

	if (ishexnum) {
		*argb32 = strtol(color_str, NULL, 16);
		return 0;
	}
	else {
		for (int i = 0; colornames[i].key; i++) {
			if (strcasecmp(colornames[i].key, color_str) == 0) {
				*argb32 = colornames[i].value;
				return 0;
			}
		}
	}
	return -1;
}

void fb_setcolor(uint32_t argb)
{
	lcd_regs->argb = argb;
}

void plot_point(int16_t x, int16_t y, uint32_t argb)
{
	if (x < 0 || x > LCD_WIDTH || y < 0 || y > LCD_HEIGHT)
		return;

	uint32_t point_addr = ((y * LCD_WIDTH) + x) * LCD_PIXELBYTES + LCD_FBADDR;
	uint16_t rgb16 = ((argb >> 8) & LCD_RED) |
					 ((argb >> 5) & LCD_GREEN) |
					 ((argb >> 3) & LCD_BLUE);
	// printf("setting address 0x%08x with 0x%04X\n", point_addr, rgb16);
	*(uint16_t *)point_addr = rgb16;
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

int plot_char(int x, int y, int fontnum, int c)
{
	uint8_t *font;
	switch (fontnum) {
	case 1:
		font = (uint8_t *)Callibri15;
		break;
	default:
		font = (uint8_t *)fixed_bold10x15;
		break;
	}
	uint16_t font_l = (font[FONT_LENGTH] << 8) + font[FONT_LENGTH + 1];
	uint8_t	 font_w = font[FONT_WIDTH];
	uint8_t	 font_h = font[FONT_HEIGHT];
	uint8_t	 font_first_c = font[FONT_FIRST_CHAR];
	uint8_t	 font_char_count = font[FONT_CHAR_COUNT];
	uint8_t *font_width_tab = &font[FONT_WIDTH_TABLE];
	uint8_t *font_tab = &font[FONT_WIDTH_TABLE]; // default is NO_CHAR_WIDTH TABLE

	if (font_l > 1) {
		// printf("Selected font has font_len=%d\n", font_l);
		font_tab = &font[FONT_WIDTH_TABLE + font_char_count];
	}

	// printf("%s(): font=%d maxwidth=%d height=%d firstchar=0x%02x font_count=%d \n",
	// 	   __func__, fontnum, font_w, font_h, font_first_c, font_char_count);

	if (c < font_first_c || c >= font_first_c + font_char_count) {
		printf("%s(): char 0x%02x out-of-range\n", __func__, c);
		return x;
	}

	// printf("first 8 bytes of font_tab: ");
	// for (int i = 0; i < 8; i++)
	// 	printf("%02X ", font_tab[i]);
	// printf("\n");

	int char_w = font_w;
	int p = 0;
	if (font_l > 1) {
		char_w = font_width_tab[c - font_first_c];
		/* find ptr to font_tab for char c */
		for (int i = 0; i < (c - font_first_c); i++) {
			p += font_width_tab[i];
		}
	}

	uint8_t *char_tab = &font_tab[(c - font_first_c) * char_w * 2];
	if (font_l > 1) {
		char_tab = &font_tab[p * 2];
	}

	// printf("char 0x%02x(%d) '%c' p=%d width=%d bytes: ", c, c, c, p, char_w);
	// for (int i = 0; i < char_w * 2; i++)
	// 	printf("%02X ", char_tab[i]);
	// printf("\n");

	/* Correct ONLY for font_h <= 16*/
	for (int i = 0; i < char_w; i++) {
		int b0 = char_tab[i];
		for (int j = 0; j < 8; j++) {
			if (b0 & (1 << j)) {
				plot_point(x + i, y + j, 0xffffffff);
			}
		}
		if (font_h < 8) {
			continue;
		}
		/* TODO: RECAL the below start and offset bits */
		int b1 = char_tab[i + char_w];
		for (int j = 1; j < 8; j++) {
			if (b1 & (1 << j)) {
				plot_point(x + i, y + j + 7, 0xffffffff);
			}
		}
	}

	return x + char_w + (font_l > 1 ? 1 : 0);
}