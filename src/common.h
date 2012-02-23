#ifndef COMMON_H
#define COMMON_H

typedef unsigned int uint;
typedef unsigned char uchar;

#include <stdint.h>
#include "str.h"

#define PI	(3.141592653589793)
#define LOG2	(0.69314718055994530941)

/* Maximum value, or "infinity", for 64-bit unsigned integer. */
#define UINT64_INF ((uint64_t)-1)

/* Source location. */
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
#define SOURCE_LOC __FILE__ ":" TOSTRING(__LINE__)

/*
 * Game object type enumeration.
 */
enum ObjType {
	OBJTYPE_TILE = 1567,	/* A magic number to not confuse it with
				   something else while debugging. */
	OBJTYPE_BODY,
	OBJTYPE_SHAPE,
	OBJTYPE_SPRITELIST,
	OBJTYPE_PARALLAX,
	OBJTYPE_CAMERA,
	OBJTYPE_WORLD,
	OBJTYPE_TIMER,
	OBJTYPE_PATH,
	OBJTYPE_USER
};

/* Suppress unused parameter warning in debug mode. */
#ifndef NDEBUG
#define UNUSED(x) ((x) = (x))
#else
#define UNUSED(x) ((void) 0)
#endif /* Debug mode. */

/*
 * Degrees to radians and radians to degrees conversion.
 */
#define DEG_RAD(angle) ((angle) * PI / 180.0)
#define RAD_DEG(angle) ((angle) * 180.0 / PI)

/* Maximum/minimum value. */
#define MAX2(a, b) ((a)>(b) ? (a) : (b))
#define MIN2(a, b) ((a)<(b) ? (a) : (b))
#define MAX3(a, b, c) MAX2(MAX2((a), (b)), (c))

/* True if x falls within interval [a,b] or [b,a]. */
#define BETWEEN(x, a, b) (((x)-(a)>=0.0) ? ((b)>=(x)) : ((b)<=(x)))

#define TOGGLE(flag) (flag) = (flag) ? 0 : 1;

#define CAMERAS_MAX	2
#define WORLDS_MAX	4
#define TILES_MAX	50000
#define EXTRA_KEYBIND	300 /* Space for mouse and joystick button bindings in key_bind. */
#define MAX_AXIS	8
#define MAX_JOYSTICKS	8

#endif /* COMMON_H */
