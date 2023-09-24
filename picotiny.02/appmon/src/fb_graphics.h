#ifndef __FB_GRAPHICS_H__
#define __FB_GRAPHICS_H__

#include <stdint.h>

typedef struct {
	const char	  *key;
	const uint32_t value;
} KEY_UINT32_PAIR;

extern const KEY_UINT32_PAIR colornames[];

const char *colorname(uint32_t argb);
int str2argb32(const char *color_str, uint32_t *argb32);
void fb_setcolor(uint32_t argb);

void plot_point(int16_t x, int16_t y, uint32_t argb);
int plot_line(int x0, int y0, int x1, int y1, uint32_t argb);
int plot_circle(int xm, int ym, int r, uint32_t argb);
int plot_char(int x, int y, int font, int c);

#endif /* __FB_GRAPHICS_H__ */