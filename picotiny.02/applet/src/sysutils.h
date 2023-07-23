#ifndef __SYSUTILS_H__
#define __SYSUTILS_H__

#define ARRAY_SIZE(array) (sizeof(array) / sizeof(array[0]))
#define UDIV_UP(a, b) (((a) + (b)-1) / (b))
#define ALIGN_UP(multiple_of, a) \
	(UDIV_UP(a, multiple_of) * (multiple_of))
#define SIGN(val) ((0 < val) - (val < 0))
#ifndef MIN
#define MIN(A, B) ({ __typeof__(A) __a = (A); \
		__typeof__(B) __b = (B); __a < __b ? __a : __b; })
#endif
#ifndef MAX
#define MAX(A, B) ({ __typeof__(A) __a = (A); \
		__typeof__(B) __b = (B); __a < __b ? __b : __a; })
#endif
#define BOUND(low, x, high) ({\
		__typeof__(x) __x = (x); \
		__typeof__(low) __low = (low); \
		__typeof__(high) __high = (high); \
		__x > __high ? __high : (__x < __low ? __low : __x); })
#define MAP(x, in_lo, in_hi, out_lo, out_hi) \
	(((x)-in_lo) * (out_hi - out_lo) / (in_hi - in_lo) + out_lo)

inline long map(long x, long in_min, long in_max, long out_min, long out_max)
{
	return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}
inline float mapf(float x, float in_min, float in_max, float out_min, float out_max)
{
	return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

#define stringify_literal(x)	 #x
#define stringify_expanded(x)	 stringify_literal(x)
#define stringify_with_quotes(x) stringify_expanded(stringify_expanded(x))

#endif /* __SYSUTILS_H__ */