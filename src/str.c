#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mem.h"
#include "str.h"

#define STRING_MAX_SZ 1000

/*
 * Set the size of the string. Size is always
 * 	strlen(s->data) + 1, assuming no extra '\0' characters in the middle.
 * Thus setting the size to zero doesn't really make sense.
 * str_setsz() forces the new string to be zero terminated.
 */
void
str_setsz(String *s, uint new_size)
{
	assert(str_isvalid(s) && new_size > 0 && new_size <= STRING_MAX_SZ);

	if (s->size == new_size)
		return;
	if (new_size == 1) {
		/* Free. */
		mem_free(s->data);
		s->size = 1;
		s->data = "";
		return;
	}
	if (s->size == 1) {
		/* Allocate. */
		s->data = (char *)mem_alloc(new_size, "String buffer");
		s->size = new_size;
		s->data[new_size-1] = '\0';
		return;
	}
	
	/* Reallocate. */
	mem_realloc((void **)&s->data, new_size, "String buffer");
	s->size = new_size;
	s->data[new_size-1] = '\0';
}

/*
 * Do snprintf() on our string.
 */
void
str_sprintf(String *s, const char *fmt, ...)
{
	int n;
	va_list ap;

	assert(str_isvalid(s) && fmt != NULL);
	
	va_start(ap, fmt);
	n = vsnprintf(NULL, 0, fmt, ap);
	assert(n >= 0);
	va_end(ap);

	va_start(ap, fmt);
	str_setsz(s, n + 1);
	vsnprintf(s->data, s->size, fmt, ap);
	va_end(ap);
}

void
str_assign(String *s, const String *copy)
{
	assert(str_isvalid(s) && str_isvalid(copy));
	str_destroy(s);
	str_append(s, copy);
}

void
str_assign_cstr(String *s, const char *copy)
{
	assert(str_isvalid(s) && copy != NULL);
	str_destroy(s);
	str_append_cstr(s, copy);
}

void
str_append(String *s, const String *tail)
{
	int n;
	assert(str_isvalid(s) && str_isvalid(tail));

	n = s->size;
	str_expand(s, tail->size - 1);
	strcpy(s->data + n - 1, tail->data);
}

/*
 * Append [cstr] to [s].
 */
void
str_append_cstr(String *s, const char *cstr)
{
	assert(str_isvalid(s) && cstr != NULL);

        uint cstr_len = strlen(cstr);
        if (cstr_len == 0)
                return;
        uint old_size = s->size;
	str_expand(s, cstr_len);
	strcpy(s->data + old_size - 1, cstr);
}

