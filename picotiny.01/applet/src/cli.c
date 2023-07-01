#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <stdlib.h>

#include "picotiny_hw.h"
#include "cli.h"
#include "sysutils.h"

int errno;

static char	   kbuf[CLI_KBUF_MAX];
static uint8_t kbuf_count = 0;
static char	  *cliargs[CLI_MAX_TOKENS];
static bool	   prompt_shown = false;

int cmd_help(int argc, char *argv[]);
int cmd_clearscreen(int argc, char *argv[]);
int cmd_version(int argc, char *argv[]);
int cmd_memdump(int argc, char *argv[]);
int cmd_memwrite(int argc, char *argv[]);
int cmd_showmap(int argc, char *argv[]);

// clang-format off
const CMD_ENTRY cmd_table[] = {
	{ "?",		cmd_help		},
	{ "help",	cmd_help		},
	{ "cls",	cmd_clearscreen	},
	{ "ver",	cmd_version		},
	{ "md",		cmd_memdump		},
	{ "mw",		cmd_memwrite	},
	{ "map",	cmd_showmap		},
	{ 0, 0 },
};
// clang-format on

int nb_getline(void)
{
	int c = 0, esc = 0;

	while ((c = getchar_timeout_us(0)) > 0) {

		switch (c) {
		case '\n':
		case '\r':
			putchar('\n');
			kbuf[kbuf_count] = 0;
			return kbuf_count;
		case '\e':
			if (esc)
				esc = 0;
			else
				esc = 1;
			break;
		case '\b':
			if (esc) {
				esc = 0;
				// readline interpretes as kill-word
				// but here ignore
			}
			else {
				if (kbuf_count > 0) {
					putchar_raw(c);
					putchar_raw(' ');
					putchar_raw(c);
					kbuf_count--;
				}
			}
			break;
		default:
			if (esc == 1) {
				// interpret escape first char
				esc = 2;
			}
			else if (esc == 2) {
				// interpret escape second char
				esc = 0;
			}
			else if (isprint(c) && (kbuf_count < CLI_KBUF_MAX - 1)) {
				kbuf[kbuf_count++] = c;
				putchar_raw(c);
			}
			break;
		}
	}
	return -1;
}

/* performs like strtok(), except this one does quoted arguments */
int cli_splitstring(char *p, char *argv[])
{
	int num_toks = 0;
	int state = ' ';
	while (*p) {
		switch (state) {
		case ' ':
			if (isspace((int)*p))
				break;
			argv[num_toks] = p;
			if (*p == '\'')
				state = 'Q'; // begin single-quote state
			else if (*p == '\"')
				state = 'D'; // begin double-quote state
			else
				state = 'T'; // begin normal alpha state
			break;
		case 'T':
			if (isspace((int)*p)) {
				// end of unquoted text
				*p = 0;
				num_toks++;
				state = ' '; // back to whitespace idle
			}
			break;
		case 'Q':
			if (*p == '\'') {
				// end of single-quoted text
				*p = 0;
				/* adjust prev-entered tok_start to remove leading quote */
				argv[num_toks] += 1;
				num_toks++;
				state = ' '; // back to whitespace idle
			}
			break;
		case 'D':
			if (*p == '\"') {
				// end of double-quoted text
				*p = 0;
				/* adjust prev-entered tok_start to remove leading quote */
				argv[num_toks] += 1;
				num_toks++;
				state = ' '; // back to whitespace idle
			}
			break;
		}
		p++;
	} // end while

	if (state != ' ') {
		num_toks++;
	}
	return num_toks;
}

int do_nonblock_cli(void)
{
	int				 argc;
	const CMD_ENTRY *cmd_p;

	if (!prompt_shown) {
		memset(kbuf, 0, sizeof(kbuf));
		cliargs[0] = kbuf;
		kbuf_count = 0;
		printf(CLI_PROMPT);
		fflush(stdout);
		prompt_shown = true;
	}

	/* if nb_getlne returns negative, no full line is collected yet */
	if (nb_getline() < 0)
		return 0;

	prompt_shown = false;
	argc = cli_splitstring(kbuf, cliargs);

	cmd_p = cmd_table;
	if (strlen(cliargs[0]) != 0) {
		while ((cmd_p->name != 0) && (strcmp(cmd_p->name, cliargs[0]) != 0)) {
			cmd_p++;
		}
		if (cmd_p->name != 0) {
			kbuf_count = 0;
			return (cmd_p->func(argc, cliargs));
		}
		printf("Command <%s> not found.\n", cliargs[0]);
	}

	return -1;
}

int anyopts(int argc, char *argv[], char *needle)
{
	for (int i = 1; i < argc; i++) {
		if (strcmp(argv[i], needle) == 0)
			return i;
	}
	return -1;
	// usage:
	// if (res > 0)
	//	printf("opt %s found at %d\n", argv[res], res);
}

void pr_bits(uint32_t val, int start_bitnum, int len, unsigned grouping)
{
	if (start_bitnum > 31 || ((start_bitnum + len - 1) > 31))
		return;

	for (int i = start_bitnum + len - 1; i >= start_bitnum; i--) {
		printf("%c", (val & (1 << i)) ? '1' : '0');
		if (grouping && (i % grouping) == 0 && i != start_bitnum) {
			printf(" ");
		}
	}
}

void pr_hex_dump(uint32_t addr, uint8_t *buf, int len)
{
	int rounded_up_len = ALIGN_UP(16, len);
	int ascii_to_display = 16;

	for (int i = 0; i < rounded_up_len; i++) {
		if ((i % 16) == 0) {
			printf("%08lx ", addr + i);
		}
		if ((i % 8) == 0) {
			printf(" "); // print column spacer for 8-byte block
		}
		if (i < len) {
			printf("%02x ", buf[i]);
		}
		else {
			printf("   ");
		}
		if (((i + 1) % 16) == 0) {
			printf(" ");
			if (i >= len) {
				// instead of 16 ascii, print less
				ascii_to_display -= (rounded_up_len - len);
			}
			for (int j = 0; j < ascii_to_display; j++) {
				char c = buf[j + (i / 16) * 16];
				printf("%c", isprint(c) ? c : '.');
			}
			printf("\n");
		}
	}
}

int cmd_help(int argc, char *argv[])
{
	CMD_ENTRY *cmd_p = (CMD_ENTRY *)cmd_table;
	printf("Commands available:\n");
	while (cmd_p->name != 0) {
		printf("%s, ", cmd_p->name);
		cmd_p++;
	}
	printf("\b\b. \n");
	return 0;
}

int cmd_clearscreen(int argc, char *argv[])
{
	printf("\e[H\e[J");
	return 0;
}

int cmd_version(int argc, char *argv[])
{
	printf("PicoSoc mon ver=0.0.1\n");
	return 0;
}

int cmd_memdump(int argc, char *argv[])
{
	const int block_len = 256;
	uint8_t	  buffer[block_len];
	bool	  havekey, quit = false;
	uint32_t  addr = 0;
	int		  c;

	if (argc < 2) {
		printf("Usage: %s <address>\n", argv[0]);
		return -1;
	}
	addr = strtoul(argv[1], NULL, 0);
	// round off to 512-byte boundary
	addr &= ~(512 - 1);

	do {
		memcpy(buffer, (uint8_t *)addr, block_len);
		pr_hex_dump(addr, buffer, block_len);

		printf("...");
		fflush(stdout);

		havekey = false;
		do {
			do {
				c = getchar_timeout_us(0);
			} while (c < 0);
			switch (c) {
			case 'p':
				havekey = true;
				addr = 0;
				break;
			case '1':
				havekey = true;
				addr += 0x1000;
				break;
			case '2':
				havekey = true;
				addr += 0x10000;
				break;
			case '3':
				havekey = true;
				addr += 0x100000;
				break;
			case '!':
				havekey = true;
				addr -= 0x1000;
				break;
			case '@':
				havekey = true;
				addr -= 0x10000;
				break;
			case '#':
				havekey = true;
				addr -= 0x100000;
				break;
			case ' ':
			case 'n':
			case 'N':
				havekey = true;
				addr += block_len;
				break;
			case 'b':
			case 'B':
				havekey = true;
				addr -= block_len;
				break;
			case 'q':
			case 'Q':
			case 0x3:
				havekey = true;
				quit = true;
				break;
			default:
				break;
			}
		} while (!havekey);
		printf("\n");
	} while (!quit);

	return 0;
}

int cmd_memwrite(int argc, char *argv[])
{
	uint32_t addr;
	int		 argnum, numbytes = 0;
	int		 res = 0;
	uint8_t	 buf[256], *mem_p;

	if (argc < 3) {
		goto usage;
	}
	addr = strtoul(argv[1], NULL, 0);

	for (argnum = 2; argnum < argc; argnum++) {
		char *argp = argv[argnum];
		int	  arglen = strlen(argp);
		bool  is_text = false;
		for (char *cp = argp; *cp; cp++)
			if (!(isxdigit((int)*cp) || tolower(*cp) == 'x'))
				is_text = true;
		if (is_text || arglen > 4) {
			// printf("%s: found beginning of string for param(%d) %s\n", argv[0], argnum, argp);
			for (int i = 0; i < arglen; i++) {
				buf[numbytes++] = argp[i];
			}
		}
		else {
			int v = strtol(argp, NULL, 0);
			if (v >= 0 || v <= 255) {
				buf[numbytes++] = v;
			}
			else {
				goto arg_error;
			}
		}
	}

	printf("%s: writing mem at addr 0x%x with %d bytes:\n",
		   argv[0], addr, numbytes);
	for (int i = 0; i < numbytes; i++)
		printf("0x%02x ", buf[i]);
	printf("\n");

	mem_p = (uint8_t *)addr;
	for (int i = 0; i < numbytes; i++, mem_p++) {
		*mem_p = buf[i];
	}
	return 0;

arg_error:
	printf("%s: error: data parameter %d\n", argv[0], argnum - 3);
	return -1;
usage:
	printf("Usage: %s <addr> <\"string\"|byte> [\"strings\"|<bytes>...]\n", argv[0]);
	return -1;
}

int cmd_showmap(int argc, char *argv[])
{
	printf("0x00000000 - 0x007FFFFF 8MiB SPI Flash XIP\n"
		   "0x40000000 - 0x40001FFF 8KiB SRAM\n"
		   "0x80000000 - 0x8FFFFFFF PicoPeripherals\n"
		   "    0x80000000 - 0x80001FFF 8KiB BROM\n"
		   "    0x81000000 - 0x8100000F SPI Flash Config / Bitbang IO\n"
		   "    0x82000000 - 0x8200000F GPIO\n"
		   "    0x83000000 - 0x8300000F UART\n"
		   "0xC0000000 - 0xFFFFFFFF PSRAM region\n");
	return 0;
}