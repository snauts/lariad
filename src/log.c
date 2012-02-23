#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

static FILE *log_file = NULL;

/*
 * Logging levels - error, warning, unspecified.
 */
#define LOG_NONE 0
#define LOG_MSG 1
#define LOG_WARN 2
#define LOG_ERR 3

/*
 * Write message to log file.
 *
 * level	Error (LOG_ERR), warning (LOG_WARN), message(LOG_MSG), or
 *		unspecified (LOG_NONE).
 * fmt		Message text (format string, just like for printf()).
 * ap           Variable length argument list for vfprintf() to parse.
 */
static void
write(int level, const char *fmt, va_list ap)
{
	assert(log_file != NULL);

	switch (level) {
	case LOG_ERR:
		fprintf(log_file, "ERROR: ");
		break;
	case LOG_WARN:
		fprintf(log_file, "WARNING: ");
		break;
	case LOG_MSG:
	case LOG_NONE:
		break;
	default:
		fprintf(log_file, "Invalid log level: %i.", level);
		abort();
	}

	/* Write log message, and flush the stream. */
	vfprintf(log_file, fmt, ap);
	if (level != LOG_NONE)
		fprintf(log_file, "\n");
	fflush(log_file);
}

/*
 * Initialize log tags (LOG_MSG, LOG_ERR, LOG_WARN) and open log file.
 *
 * filename     Path to the file that will be opened as log file; NULL means
 *                      standard error will be used.
 */
void
log_open(const char *filename)
{
	/* Open log file (stderr is default). */
	if (filename != NULL)
		log_file = fopen(filename, "a");
	else
	        log_file = stderr;
}

/*
 * Simply write text into log output stream, without any tags or whatever.
 */
void
log_write(const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	write(LOG_NONE, fmt, ap);
	va_end(ap);
}

/*
 * Log a message.
 */
void
log_msg(const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	write(LOG_MSG, fmt, ap);
	va_end(ap);
}

/*
 * Log error message.
 */
void
log_err(const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	write(LOG_ERR, fmt, ap);
	va_end(ap);
}

/*
 * Log warning message.
 */
void
log_warn(const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	write(LOG_WARN, fmt, ap);
	va_end(ap);
}

/*
 * Log an error and abort().
 */
void
fatal_error(const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	write(LOG_ERR, fmt, ap);
	va_end(ap);
	abort();
}
