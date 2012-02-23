#ifndef COMPAT_H
#define COMPAT_H

#include <stdio.h>

/*
 * Compat module contains project-wide portability tweaks.
 */

#if 0
#if defined(_WIN32) || defined(_WIN64)
#define SYSTEM_IS_WINDOWS
#endif /* Compiling on windows. */
#endif

/*
 * snprintf() is not available on Windows.
 */
#ifdef _WIN32
#define snprintf(str, n, fmt, args...) sprintf(str, fmt, ## args)
#endif /* Windows 32-bit. */

#endif /* COMPAT_H */
