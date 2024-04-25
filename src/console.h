#ifndef CONSOLE_H
#define CONSOLE_H

#include "common.h"

#define CONSOLE_MAX_LINES	5
#define CONSOLE_MAX_LINE_SIZE	80

typedef struct {
	char		buffer[CONSOLE_MAX_LINES][CONSOLE_MAX_LINE_SIZE];
	uint64_t	log_time[CONSOLE_MAX_LINES];
	uint		last_line;
} Console;

#endif /* CONSOLE_H */
