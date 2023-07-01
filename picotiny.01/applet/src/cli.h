#ifndef __CLI_H__
#define __CLI_H__

#define CLI_KBUF_MAX   128
#define CLI_MAX_TOKENS 32

#define FPNAME_MAXLEN  255
#ifndef PATH_MAX
#define PATH_MAX FPNAME_MAXLEN
#endif

#define CLI_PROMPT "\e[1;36mpicomon> \e[0m"

typedef struct CMD_ENTRY {
	const char *name;
	const int (*func)(int argc, char *argv[]);
} CMD_ENTRY;

int nb_getline(void);
int do_nonblock_cli(void);
int anyopts(int argc, char *argv[], char *needle);
void pr_bits(uint32_t val, int start_bitnum, int len, unsigned grouping);
void pr_hex_dump(uint32_t addr, uint8_t *buf, int len);

#endif /* __CLI_H__ */