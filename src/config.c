#include <assert.h>
#include <lua.h>
#include <lualib.h>
#include "log.h"
#include "lua_util.h"
#include "config.h"

static lua_State *cfg_L;	/* Lua state used by cfg_ functions. */
static int cfg_index;		/* Configuration table stack index. */

Config config;

static int
cfg_error_handler(lua_State *L)
{
	int rc;

	rc = luaL_dostring(L, "io.stderr:write(debug.traceback(\"cfg_error_handler():\",3) .. '\\n')");
	lua_pushstring(L, lua_tostring(L, 1));
	return 1;
}

void
cfg_read(const char *filename)
{
	int cfg_errfunc_index;
	
	/* Config routines use a separate Lua state. */
	cfg_L = luaL_newstate();
	luaL_openlibs(cfg_L);
	assert(cfg_L != NULL);
	
	/* Push error handler on stack. */
	lua_pushcfunction(cfg_L, cfg_error_handler);
	cfg_errfunc_index = lua_gettop(cfg_L);
	
	/* Let Lua parse the configuration file. */
	if ((luaL_loadfile(cfg_L, filename) ||
	    lua_pcall(cfg_L, 0, 0, cfg_errfunc_index))) {
		log_err("[Lua] %s", lua_tostring(cfg_L, -1));
		abort();
	}
	
	/* Leave "Cfg" table on the stack and remember its index. */
	lua_getglobal(cfg_L, "Cfg");		/* ... cfg */
	cfg_index = lua_gettop(cfg_L);
}

void
cfg_close()
{
	lua_close(cfg_L);
}

double
cfg_get_double(const char *key)
{
	double result;

	assert(cfg_L != NULL && key != NULL);
	lua_pushstring(cfg_L, key);	/* ... key */
	lua_rawget(cfg_L, cfg_index);	/* ... value */
	result = L_getstk_double(cfg_L, -1);
	lua_pop(cfg_L, 1);		/* ... */
	return result;
}

void
cfg_get_str(const char *key, String *result)
{	
	assert(cfg_L != NULL && key != NULL && str_isvalid(result));
	lua_pushstring(cfg_L, key);		/* ... key */
	lua_rawget(cfg_L, cfg_index);	/* ... str? */
	L_assert(cfg_L, lua_isstring(cfg_L, -1), "String expected.");
	str_sprintf(result, lua_tostring(cfg_L, -1));
	lua_pop(cfg_L, 1);			/* ... */
}

void
cfg_get_color(const char *key, float color[4])
{
	assert(cfg_L != NULL && key != NULL && color != NULL);
	lua_pushstring(cfg_L, key);		/* ... key */
	lua_rawget(cfg_L, cfg_index);	/* ... tbl? */
	L_assert(cfg_L, lua_istable(cfg_L, -1), "Table expected.");
	L_getstk_color(cfg_L, -1, color);
	lua_pop(cfg_L, 1);
}

int
cfg_get_int(const char *key)
{
	int result;

	assert(cfg_L != NULL && key != NULL);
	lua_getfield(cfg_L, cfg_index, key);/* ... Num? */
	L_assert(cfg_L, lua_isnumber(cfg_L, -1), "Integer expected");
	result = lua_tointeger(cfg_L, -1);
	lua_pop(cfg_L, 1);			/* ... */
	return result;
}

int
cfg_has_field(const char *key)
{
	assert(cfg_L != NULL && key != NULL);
	lua_getfield(cfg_L, cfg_index, key);
        int has = !lua_isnil(cfg_L, -1);
        lua_pop(cfg_L, 1);
	return has;
}

int
cfg_get_bool(const char *key)
{
	int result;

	assert(cfg_L != NULL && key != NULL);
	lua_getfield(cfg_L, cfg_index, key);	/* ... bool? */
	L_assert(cfg_L, lua_isboolean(cfg_L, -1), "Boolean value expected.");
	result = lua_toboolean(cfg_L, -1);
	lua_pop(cfg_L, 1);			/* ... */
	return result;
}
