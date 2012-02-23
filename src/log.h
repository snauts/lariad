#ifndef LOG_H
#define LOG_H

/* No logging for release builds. */
#ifdef NDEBUG

#define	log_open(filename)	((void)0)
#define	log_err(fmt, ...)	((void)0)
#define	log_warn(fmt, ...)      ((void)0)
#define	log_msg(fmt, ...)       ((void)0)
void	fatal_error(const char *fmt, ...);

#else

/*
It's possible to print location of the message via macros.

#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
#define SOURCE_LOC __FILE__ ":" TOSTRING(__LINE__)
#define log_msg(fmt, args...)	\
	_log_msg(fmt " (" SOURCE_LOC ")", ## args);
*/

void	log_open(const char *filename);
void	log_err(const char *fmt, ...);
void	log_warn(const char *fmt, ...);
void	log_msg(const char *fmt, ...);
void	log_write(const char *fmt, ...);
void	fatal_error(const char *fmt, ...);

#endif /* NDEBUG */

#endif /* LOG_H */
