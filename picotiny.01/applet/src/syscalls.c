// https://github.com/pro-codes090/Stm32-SDcard-library/blob/main/Src/syscalls.c#L78

#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "hwdefs.h"
#include "picotiny_hw.h"

/* Foobar with C-compilers, see:
 * https://stackoverflow.com/questions/16831605/strange-compiler-warning-c-warning-struct-declared-inside-parameter-list
 */
struct _reent *wut;
struct tms	  *_tms_buf;


int _getpid(void)
{
	return 1;
}

int _kill(int pid, int sig)
{
	errno = EINVAL;
	return -1;
}

void _exit(int status)
{
	_kill(status, -1);
	while (1) {
	} /* Make sure we hang here */
}

extern unsigned char _heap_end;

void *_sbrk(int incr)
{
#if 1
	static unsigned char *heap = NULL;
	unsigned char		 *prev_heap;
	if (heap == NULL) {
		heap = (unsigned char *)&_heap_end;
	}
	prev_heap = heap;
	heap += incr;
	return prev_heap;
#else
	errno = ENOMEM;
	return (char *)-1;
#endif
}

__attribute__((weak)) int _read(int file, char *ptr, int len)
{
	int DataIdx;

	for (DataIdx = 0; DataIdx < len; DataIdx++) {
		*ptr++ = __io_getchar();
	}
	return len;
}

__attribute__((weak)) int _write(int file, char *ptr, int len)
{
	int DataIdx;

	for (DataIdx = 0; DataIdx < len; DataIdx++) {
		__io_putchar(*ptr++);
	}
	return len;
}

int _close(int file)
{
	return -1;
}

int _fstat(int file, struct stat *st)
{
	st->st_mode = S_IFCHR;
	return 0;
}

int _isatty(int file)
{
	return 1;
}

int _lseek(int file, int ptr, int dir)
{
	return 0;
}

int _open(char *path, int flags, ...)
{
	/* Pretend like we always fail */
	return -1;
}

int _wait(int *status)
{
	errno = ECHILD;
	return -1;
}

int _unlink(char *name)
{
	errno = ENOENT;
	return -1;
}

int _times(struct tms *buf)
{
	return -1;
}

int _stat(char *file, struct stat *st)
{
	st->st_mode = S_IFCHR;
	return 0;
}

int _link(char *old, char *new)
{
	errno = EMLINK;
	return -1;
}

int _fork(void)
{
	errno = EAGAIN;
	return -1;
}

int _execve(char *name, char **argv, char **env)
{
	errno = ENOMEM;
	return -1;
}