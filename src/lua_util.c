#include <assert.h>
#include <math.h>
#include <lua.h>
#include <SDL.h>
#include "log.h"
#include "lua_util.h"
#include "str.h"
#include "geometry.h"
#include "config.h"

/*
 * Lua utility routines.
 */

/*
 * Print Lua stack (for debugging purposes).
 */
void
L_printstk(lua_State *L, const char *prefix)
{
	int i, n;
	String s, msg;
	
	n = lua_gettop(L);

	str_init(&s);
	str_init(&msg);
	str_sprintf(&msg, "%s: ", prefix);
	for (i = 1; i <= n; i++) {
		str_sprintf(&s, "%s(#=%i) ", lua_typename(L, lua_type(L, i)),
		    lua_objlen(L, i));
		str_append(&msg, &s);
	}
	log_msg("%s", msg.data);
	str_destroy(&s);
	str_destroy(&msg);
}

/*
 * Convert object type enum to a name. Return pointer to static string.
 */
const char *
L_objtype_name(int type)
{
	static char str[40];

	switch (type) {
	case 0: return "(destroyed?)";
	case OBJTYPE_TILE: return "Tile";
	case OBJTYPE_BODY: return "Body";
	case OBJTYPE_SHAPE: return "Shape";
	case OBJTYPE_SPRITELIST: return "SpriteList";
	case OBJTYPE_PARALLAX: return "Parallax";
	case OBJTYPE_CAMERA: return "Camera";
	case OBJTYPE_WORLD: return "World";
	case OBJTYPE_TIMER: return "Timer";
	case OBJTYPE_PATH: return "Path";
	default:
		snprintf(str, 40, "(unknown: %i)", type);
		return str;
	}
}

/*
 * Convert status code enum to its description. Return pointer to static string.
 */
const char *
L_statstr(int status_code)
{
	switch (status_code) {
	case L_OK: return "It's OK!!";
	case L_NEGATIVE_RADIUS: return "Circle with negative radius.";
	case L_FRACTIONAL_RADIUS: return "Fractional radius. Please use integers.";
	case L_FRACTIONAL_OFFSET: return "Fractional offset. Please use integers.";
	case L_INVALID_SHAPE_SPEC: return "Invalid shape specification.";
	default: return "Unknown status code.";
	}
}

/*
 * Extract number from a table.
 */
double
L_getfield_double(lua_State *L, int index, const char *key)
{
	double result;

	if (index < 0)
		index += lua_gettop(L) + 1;
	
	assert(L != NULL && key != NULL);
	assert(lua_istable(L, index));	/* ... {?} ... */
	lua_getfield(L, index, key);	/* ... {?} ... number? */
	assert(lua_isnumber(L, -1));	/* ... {?} ... number */
	result = lua_tonumber(L, -1);
	lua_pop(L, 1);			/* ... {?} ... */
	return result;
}

/*
 * Get vect_f, as represented by Lua table {x, y}, or {x=?, y=?}, from the
 * stack.
 */
vect_f
L_getstk_vect_f(lua_State *L, int index)
{
	vect_f result;

	if (index < 0)
		index += lua_gettop(L) + 1;

	L_assert(L, lua_istable(L, index), "Table expected for vect_f.");
 
	lua_pushnumber(L, 1);
	lua_gettable(L, index);
	if (lua_isnumber(L, -1)) {
		lua_pushnumber(L, 2);
		lua_gettable(L, index);
	} else {
		lua_pop(L, 1);
		lua_getfield(L, index, "x");
		lua_getfield(L, index, "y");
	}
	L_assert(L, !lua_isnil(L, -1) && !lua_isnil(L, -2), "Doesn't look like a vector.");
	result.x = lua_isnil(L, -2) ? 0.0 : lua_tonumber(L, -2);
	result.y = lua_isnil(L, -1) ? 0.0 : lua_tonumber(L, -1);
	lua_pop(L, 2);
	return result;
}

/*
 * Get vect_i, as represented by Lua table {x, y}, or {x=?, y=?}, from the
 * stack.
 */
vect_i
L_getstk_vect_i(lua_State *L, int index)
{
	double x, y;
	vect_i result;

	if (index < 0)
		index += lua_gettop(L) + 1;

	L_assert(L, lua_istable(L, index), "Table expected for vect_i.");
 
	lua_pushnumber(L, 1);
	lua_gettable(L, index);
	if (lua_isnumber(L, -1)) {
		lua_pushnumber(L, 2);
		lua_gettable(L, index);
	} else {
		lua_pop(L, 1);
		lua_getfield(L, index, "x");
		lua_getfield(L, index, "y");
	}
	L_assert(L, !lua_isnil(L, -1) && !lua_isnil(L, -2),
	    "Doesn't look like a vector.");
	x = lua_isnil(L, -2) ? 0.0 : lua_tonumber(L, -2);
	y = lua_isnil(L, -1) ? 0.0 : lua_tonumber(L, -1);
	lua_pop(L, 2);
	
	L_assert(L, x == floor(x) && y == floor(y),
	    "Integer vector was expected, got this: {x=%f,y=%f}.", x, y);
	result.x = (int)x;
	result.y = (int)y;
	return result;
}

void
L_getstk_BB(lua_State *LS, int index, BB *bb)
{
	double L, B, R, T;
	assert(bb != NULL);

	if (index < 0)
		index += lua_gettop(LS) + 1;

	L_assert(LS, lua_istable(LS, index),
	    "Expected bounding box in the form {l=?, r=?, b=?, t=?}.");
	lua_getfield(LS, index, "l");
	lua_getfield(LS, index, "b");
	lua_getfield(LS, index, "r");
	lua_getfield(LS, index, "t");
	L_assert(LS, lua_isnumber(LS, -1) && lua_isnumber(LS, -2) &&
	  lua_isnumber(LS, -3) && lua_isnumber(LS, -4),
	    "Expected bounding box in the form {l=?, r=?, b=?, t=?}.");
	
	/* Get the bounding box values. */    
	L = lua_tonumber(LS, -4);
	B = lua_tonumber(LS, -3);
	R = lua_tonumber(LS, -2);
	T = lua_tonumber(LS, -1);
	
	/* Assign to bounding box by casting them to integers. */
	bb->l = (int)L;
	bb->b = (int)B;
	bb->r = (int)R;
	bb->t = (int)T;
	
	/* Verify that they were integers. */
	L_assert(LS, (double)bb->l == L && (double)bb->b == B &&
	    (double)bb->r == R && (double)bb->t == T,
	    "Bounding box values should be integers.");
	
	lua_pop(LS, 4);
}

void
L_getstk_TexFrag(lua_State *L, int index, TexFrag *tf)
{
	assert(tf != NULL);

	if (index < 0)
		index += lua_gettop(L) + 1;

	L_assert(L, lua_istable(L, index),
	    "Expected bounding box in the form {l=?, r=?, b=?, t=?}.");
	lua_getfield(L, index, "l");
	lua_getfield(L, index, "b");
	lua_getfield(L, index, "r");
	lua_getfield(L, index, "t");
	L_assert(L, lua_isnumber(L, -1) && lua_isnumber(L, -2) &&
	  lua_isnumber(L, -3) && lua_isnumber(L, -4),
	    "Expected bounding box in the form {l=?, r=?, b=?, t=?}.");
	tf->l = lua_tonumber(L, -4);
	tf->b = lua_tonumber(L, -3);
	tf->r = lua_tonumber(L, -2);
	tf->t = lua_tonumber(L, -1);
	lua_pop(L, 4);
}

/*
 * Look at stack position [index], figure out what type of shape the table that
 * should sit there represents, and store it in [s]. Here are the
 * representations, one of which is expected:
 *	{{cx, cy}, r}				-- circle
 *	{l=?, r=?, b=?, t=?}			-- rectangle
 *
 * NOTE: Shape must not be initialized because it will not be destroyed.
 */
int
L_getstk_shape(lua_State *L, int index, vect_i offset, Shape *s)
{
	double radius;
	vect_i tmp_offset;

	assert(s != NULL);
	assert(lua_istable(L, index));		/* ... {?} ... */
	
	if (index < 0)
		index += lua_gettop(L) + 1;

	/* A circle? */
	if (lua_objlen(L, index) == 2) {
		s->shape_type = SHAPE_CIRCLE;
		
		lua_pushnumber(L, 1);			/* ... 1 */
		lua_gettable(L, index);			/* ... center */
		
		tmp_offset = L_getstk_vect_i(L, -1);
		offset.x += tmp_offset.x;
		offset.y += tmp_offset.y;
		
		lua_pushnumber(L, 2);			/* ... center 2 */
		lua_gettable(L, index); 		/* ... center radius? */
		assert(lua_isnumber(L, -1));		/* ... center radius */
		radius = lua_tonumber(L, -1);
		if (radius <= 0)
			return L_NEGATIVE_RADIUS;
		if (radius == floor(radius))
			return L_FRACTIONAL_RADIUS;
			
		/* Assign radius and offset to shape. */
		s->shape.circle.radius = (int)radius;
		s->shape.circle.offset = offset;
		
		lua_pop(L, 2);				/* ... */
		return L_OK;
	}

	/* Rectangle specified as a bounding box? */
	lua_pushstring(L, "l");		/* ... "l" */
	lua_gettable(L, index);		/* ... ? */
	if (!lua_isnil(L, -1)) {
		s->shape_type = SHAPE_RECTANGLE;
		L_getstk_BB(L, index, &s->shape.rect);
		L_assert(L, bb_valid(s->shape.rect), "Invalid rectangle spec --"
		    " {l=%d,r=%d,b=%d,t=%d}.", s->shape.rect.l, s->shape.rect.r,
		    s->shape.rect.b, s->shape.rect.t);
		bb_add_vect(&s->shape.rect, offset.x, offset.y);
		lua_pop(L, 1);
		return L_OK;
	}
	
	lua_pop(L, 1);
	return L_INVALID_SHAPE_SPEC;
}

/*
 * Read a table in the form {first, second} from stack and put the boolean
 * values into [first] and [second].
 */
void
L_getstk_boolpair(lua_State *L, int index, int *first, int *second)
{
	if (index < 0)
		index += lua_gettop(L) + 1;

	assert(first != NULL && second != NULL);
	L_assert(L, lua_istable(L, index), "Table (pair of boolean values) "
	    "expected.");
	lua_pushnumber(L, 1);		/* ... pair ... 1 */
	lua_gettable(L, index);		/* ... pair ... first */
	lua_pushnumber(L, 2);		/* ... pair ... first 2 */
	lua_gettable(L, index);		/* ... pair ... first second */
	L_assert(L, lua_isboolean(L, -2) && lua_isboolean(L, -1),
	    "Expected two boolean values.");
	*first = lua_toboolean(L, -2);
	*second = lua_toboolean(L, -1);
	lua_pop(L, 2);			/* ... pair ... */
}

void
L_getstk_color(lua_State *L, int index, float color[4])
{
	if (index < 0)
		index += lua_gettop(L) + 1;
	lua_getfield(L, index, "r");
	lua_getfield(L, index, "g");
	lua_getfield(L, index, "b");
	lua_getfield(L, index, "a");
	color[0] = lua_tonumber(L, -4);
	color[1] = lua_tonumber(L, -3);
	color[2] = lua_tonumber(L, -2);
	color[3] = lua_isnil(L, -1) ? 1.0 : lua_tonumber(L, -1);
	lua_pop(L, 4);
}

void
L_push_vect_f(lua_State *L, vect_f v)
{
	lua_createtable(L, 0, 2);	/* ... {} */
	lua_pushnumber(L, v.x);		/* ... {} x */
	lua_setfield(L, -2, "x");	/* ... {x=x} */
	lua_pushnumber(L, v.y);		/* ... {x=x} y */
	lua_setfield(L, -2, "y");	/* ... {x=x, y=y} */
}

void
L_push_vect_i(lua_State *L, vect_i v)
{
	lua_createtable(L, 0, 2);	/* ... {} */
	lua_pushnumber(L, v.x);		/* ... {} x */
	lua_setfield(L, -2, "x");	/* ... {x=x} */
	lua_pushnumber(L, v.y);		/* ... {x=x} y */
	lua_setfield(L, -2, "y");	/* ... {x=x, y=y} */
}

void
L_push_BB(lua_State *L, const BB *bb)
{
	lua_createtable(L, 0, 4);
	lua_pushnumber(L, bb->l);
	lua_setfield(L, -2, "l");
	lua_pushnumber(L, bb->r);
	lua_setfield(L, -2, "r");
	lua_pushnumber(L, bb->b);
	lua_setfield(L, -2, "b");
	lua_pushnumber(L, bb->t);
	lua_setfield(L, -2, "t");
}

/* Push {boolean, boolean} */
void
L_push_boolpair(lua_State *L, int first, int second)
{
	lua_createtable(L, 2, 0);
	lua_pushnumber(L, 1);
	lua_pushboolean(L, first);
	lua_settable(L, -3);
	lua_pushnumber(L, 2);
	lua_pushboolean(L, second);
	lua_settable(L, -3);
}

void
L_push_worldData(lua_State *L, const World *world)
{
	assert(world != NULL && world->objtype == OBJTYPE_WORLD);
	
	/* Create & fill a table with world data. */
	lua_newtable(L);			/* ... {} */
	lua_pushstring(L, "now");
	lua_pushnumber(L, world->step * world->step_sec);
	lua_rawset(L, -3);
	lua_pushstring(L, "stepSec");
	lua_pushnumber(L, world->step_sec);
	lua_rawset(L, -3);
	lua_pushstring(L, "step");
	lua_pushnumber(L, world->step);
	lua_rawset(L, -3);
}

void
L_push_bodyData(lua_State *L, const Body *body, void *script_ptr)
{
	vect_i delta;
	UNUSED(script_ptr);
	assert(body != NULL && body->objtype == OBJTYPE_BODY);
	
	/* Create and fill a table with body data. */
	lua_newtable(L);			/* ... {} */
	lua_pushstring(L, "pos");
	L_push_vect_f(L, body->pos);
	lua_rawset(L, -3);
	lua_pushstring(L, "prevPos");
	L_push_vect_f(L, body->prevstep_pos);
	lua_rawset(L, -3);
	lua_pushstring(L, "deltaPos");
	delta.x = round(body->pos.x) - round(body->prevstep_pos.x);
	delta.y = round(body->pos.y) - round(body->prevstep_pos.y);
	L_push_vect_i(L, delta);
	lua_rawset(L, -3);
}

void
L_push_shapeData(lua_State *L, const Shape *s)
{
	assert(s != NULL && s->objtype == OBJTYPE_SHAPE);
	
	/* Create and fill a table with shape data. */
	lua_newtable(L);			/* ... {} */
	lua_pushstring(L, "type");
	if (s->shape_type == SHAPE_RECTANGLE) {
		lua_pushstring(L, "rectangle");
	} else {
		log_err("Shape type (%i) not supported.", s->shape_type);
		abort();
	}
	lua_rawset(L, -3);
	lua_pushstring(L, "shape");
	L_push_BB(L, &s->go.bb);
	lua_rawset(L, -3);
	lua_pushstring(L, "body");
	lua_pushlightuserdata(L, s->body);
	lua_rawset(L, -3);
}

void
L_push_camData(lua_State *L, const Camera *cam)
{
	int x, y, view_w, view_h;
	vect_i mouse_pos;
	
	assert(cam != NULL);
	
	/* Compute mouse position in physical coordinates (NOT screen
	   coordinates). */
	SDL_GetMouseState(&x, &y);
	x = (x * config.screen_width) / config.window_width;
	y = (y * config.screen_height) / config.window_height;
	x -= cam->viewport.l;
	y -= cam->viewport.t;
	view_w = cam->viewport.r - cam->viewport.l;
	view_h = cam->viewport.b - cam->viewport.t;
	mouse_pos.x = round(cam->body.pos.x + cam->size.x*((double)x/view_w - 0.5)/cam->zoom);
	mouse_pos.y = round(cam->body.pos.y - cam->size.y*((double)y/view_h - 0.5)/cam->zoom);
	
	/* Create and fill a table with camera data. */
	lua_newtable(L);
	lua_pushstring(L, "pos");
	L_push_vect_f(L, cam->body.pos);
	lua_rawset(L, -3);
	lua_pushstring(L, "mousePos");
	L_push_vect_i(L, mouse_pos);
	lua_rawset(L, -3);
	lua_pushstring(L, "zoom");
	lua_pushnumber(L, cam->zoom);
	lua_rawset(L, -3);
}
