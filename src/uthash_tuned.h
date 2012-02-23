#ifndef UTHASH_TUNED_H
#define UTHASH_TUNED_H

#include <errno.h>
#include <string.h>
#include "uthash.h"

/*
 * Be sure to include this file instead of just `uthash.h` as it may contain
 * some important tweaks.
 */

#define HASH_FUNCTION HASH_SFH		/* Use Paul Hsieh's hash function. */
 
/*
 * The following lines provide a little more helpful uthash failure mechanism.
 */
#undef uthash_fatal
#define uthash_fatal(msg)		\
do {					\
	log_err("[uthash] %s.", msg);	\
	fatal_error(strerror(errno));	\
} while (0)

#endif /* UTHASH_TUNED_H */
