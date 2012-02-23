#ifndef STR_H
#define STR_H

#include "common.h"

/*
 * String stucture. Note that size is how many actual bytes there are in the
 * string, including the terminating '\0' character. Be sure to NEVER modify
 * this last zero byte by hand, because not only would it break compatibility
 * with C-style string routines, but also the string is first initialized to the
 * constant "" (i.e., all zero length strings point to the same string), and you
 * would effectively screw with ALL empty strings.
 */
typedef struct {
	uint	size;
	char	*data;
} String;

/* Initialize string. */
#define str_init(s)		\
do {				\
	(s)->size = 1;		\
	(s)->data = "";		\
} while (0)

#define str_isvalid(s)	((s) != NULL && (s)->size > 0 && (s)->data != NULL)

/* Length of the string. */
#define str_length(s)	(assert(str_isvalid(s)), (s)->size - 1)

/* Free string data buffer. */
#define str_destroy(s)	str_setsz((s), 1);

void	str_setsz(String *s, uint new_size);
#define	str_expand(s, sz) str_setsz((s), (s)->size + (sz))
void	str_sprintf(String *s, const char *fmt, ...);
void	str_assign(String *s, const String *copy);
void	str_assign_cstr(String *s, const char *copy);
void	str_append(String *s, const String *tail);
void	str_append_cstr(String *s, const char *cstr);

#endif /* STR_H */
