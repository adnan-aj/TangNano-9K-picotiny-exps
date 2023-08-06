#ifndef __FB_GRAPHICS_H__
#define __FB_GRAPHICS_H__

#include <stdint.h>

typedef struct {
	const char	  *key;
	const uint32_t value;
} KEY_UINT32_PAIR;

extern const KEY_UINT32_PAIR colornames[];

extern uint32_t fgcolor_argb;

int plot_point(int x, int y, uint32_t argb);
int plot_line(int x0, int y0, int x1, int y1, uint32_t argb);
int plot_circle(int xm, int ym, int r, uint32_t argb);

#endif /* __FB_GRAPHICS_H__ */