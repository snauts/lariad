#ifndef LUA_UTIL_H
#define LUA_UTIL_H

#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include "game2d.h"
#include "str.h"
#include "geometry.h"
#include "world.h"

/*
 * Lua utilities.
 * Messy :(
 */

#define L_objtype_error(L, objtype)					\
	do {								\
		log_msg("Assertion failed in " SOURCE_LOC);		\
		luaL_where((L), 1);					\
		luaL_error(L, "[Lua] %sUnexpected object type: %s.",	\
			lua_tostring((L), -1), L_objtype_name((objtype)));\
		abort();						\
	} while (0)
#ifndef NDEBUG
#define L_numarg_check(L, numargs)					\
	if (lua_gettop((L)) != (numargs)) {				\
		log_msg("Assertion failed in " SOURCE_LOC);		\
		luaL_where((L), 1);					\
		luaL_error(L, "[Lua] %sIncorrect number of arguments.",	\
		    lua_tostring((L), -1));				\
		abort();						\
	}
#define L_assert(L, cond, fmt, args...)					\
	if (!(cond)) {							\
		log_msg("Assertion failed in " SOURCE_LOC);		\
		luaL_where((L), 1);					\
		luaL_error(L, "[Lua] %sAssertion (%s) failed: " fmt,	\
		    lua_tostring((L), -1), #cond, ## args);		\
		abort();						\
	}
#define L_assert_objtype(L, object, type)				\
	if ((object) == NULL) {						\
		luaL_where((L), 1);					\
		log_msg("Assertion failed in " SOURCE_LOC);		\
		luaL_error(L, "[Lua] %sExpected %s, got NULL.",		\
		    lua_tostring((L), -1), L_objtype_name((type)));	\
		abort();						\
	} else if ((object)->objtype != (type)) {			\
		log_msg("Assertion failed in " SOURCE_LOC);		\
		luaL_where((L), 1);					\
		luaL_error(L, "[Lua] %sExpected %s, got %s.",		\
		    lua_tostring((L), -1), L_objtype_name((type)),	\
		    L_objtype_name((object)->objtype));			\
		abort();						\
	}
#else
#define luaL_checktype(...)	((void)0)
#define L_numarg_check(...)	((void)0)
#define L_assert(...)		((void)0)
#define L_assert_objtype(...)	((void)0)
#endif /* Debug mode */

/* Function return codes. */
typedef enum {
	L_OK,
	L_INVALID_SHAPE_SPEC,
	L_NEGATIVE_RADIUS,
	L_FRACTIONAL_RADIUS,
	L_FRACTIONAL_OFFSET
} L_StatusCode;

/* Misc. */
const char	*L_objtype_name(int type);
void		 L_printstk(lua_State *L, const char *prefix);
const char	*L_statstr(int status_code);

#define L_getlistitem(L, index, item_i)	\
	(lua_pushnumber((L), (item_i)),	\
	 lua_gettable((L), (index) > 0 ? (index) : (index)-1))

/* Get values from stack. */
#define L_getstk_double(L, index)	\
	(assert(lua_isnumber((L), (index))), (double)lua_tonumber((L), (index)))
vect_f	L_getstk_vect_f(lua_State *L, int index);
vect_i	L_getstk_vect_i(lua_State *L, int index);
void	L_getstk_BB(lua_State *L, int index, BB *bb);
void	L_getstk_TexFrag(lua_State *L, int index, TexFrag *tf);
int	L_getstk_shape(lua_State *L, int index, vect_i offset, Shape *s);
void	L_getstk_boolpair(lua_State *L, int index, int *first, int *second);
void	L_getstk_color(lua_State *L, int index, float color[4]);

/* Push values onto stack. */
void	L_push_vect_f(lua_State *L, vect_f v);
void	L_push_vect_i(lua_State *L, vect_i v);
void	L_push_BB(lua_State *L, const BB *bb);
void	L_push_boolpair(lua_State *L, int first, int second);
void	L_push_worldData(lua_State *L, const World *world);
void	L_push_bodyData(lua_State *L, const Body *body, void *script_ptr);
void	L_push_shapeData(lua_State *L, const Shape *s);
void	L_push_camData(lua_State *L, const Camera *cam);

#endif /* LUA_UTIL_H */
