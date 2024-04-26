#include <assert.h>
#include <lua.h>
#include <math.h>
#include <stdlib.h>
#include "game2d.h"
#include "log.h"
#include "lua_util.h"
#include "misc.h"
#include "physics.h"
#include "world.h"
#include "utlist.h"

void
body_init(Body *body, World *world, vect_f pos, uint flags)
{
	assert(body != NULL && world != NULL);

	body->objtype = OBJTYPE_BODY;
	body->world = world;
	body->prev = body->next = NULL;
	
	body->pos = pos;
	body->cPhys = 0;
	body->vel = (vect_f) { 0, 0 };
	body->gravity = (vect_f) { 0, 0 };
	body->prevstep_pos = pos;
	body->prevframe_pos = pos;
	
	body->tiles = NULL;
	body->shapes = NULL;
	body->flags = flags;

	body->step_func_id = 0;
	body->afterstep_func_id = 0;
	memset(body->timers, 0, sizeof(Timer) * BODY_TIMERS_MAX);

	body->parent = NULL;
	memset(body->children, 0, sizeof(Body *) * BODY_CHILDREN_MAX);
	
	/* Add body to world. */
	world_add_body(world, body);
}

static Body *
body_alloc()
{
	extern mem_pool mp_body;
	
	return mp_alloc(&mp_body);
}

void
body_destroy(Body *body)
{
	int i;

	assert(body != NULL);

	if (body->parent != NULL) {
		/* Remove body from its parent's child list. */
		for (i = 0; i < BODY_CHILDREN_MAX; i++) {
			if (body->parent->children[i] == body) {
				body->parent->children[i] = NULL;
				break;
			}
		}
		body->parent = NULL;	/* Unset parent link. */
	}
	/* Unlink children. */
	for (i = 0; i < BODY_CHILDREN_MAX; i++) {
		if (body->children[i] != NULL)
			body->children[i]->parent = NULL;
	}

	/* Free owned tiles. */
	while (body->tiles != NULL)
		tile_free(body->tiles);

	/* Free owned shapes. */
	while (body->shapes != NULL)
		shape_free(body->shapes);
	
	/* Remove from world's lists and iteration arrays. */
	assert(body->world != NULL);
	world_remove_body(body->world, body);
	
	memset(body, 0, sizeof(Body));
}

void
body_free(Body *body)
{
	extern mem_pool mp_body;

	body_destroy(body);
	mp_free(&mp_body, body);
}

Body *
body_new(World *world, vect_f pos, uint flags)
{
	Body *body;
	
	body = body_alloc();
	body_init(body, world, pos, flags);
	
	return body;
}

/*
 * Execute body's step function.
 *
 * body		The body whose step function will be called.
 * L		Lua state.
 * script_ptr	For normal Body objects, this is the same as the 'body' pointer.
 *		For objects such as Camera and Parallax (they contain Body
 *		objects), this should point to the Camera or Parallax objects
 *		respectively. This 'script_ptr' is the pointer that Lua scripts
 *		are getting. And scripts should not have access to the
 *		underlying body object; instead they assume that they are
 * 		dealing directly with Camera, Parallax, etc.
 */
void
body_step(Body *body, lua_State *L, void *script_ptr)
{
	extern int errfunc_index;
	extern int callfunc_index;
	World *world;
	
	if (body->cPhys) {
	    vect_f impulse, delta;
	    impulse = vect_f_scale(body->gravity, body->world->step_sec);
	    body->vel = vect_f_add(body->vel, impulse);
	    delta = vect_f_scale(body->vel, body->world->step_sec);
	    body_set_pos(body, vect_f_add(body->pos, delta));
	    return;
	}

	assert(body != NULL && body->step_func_id >= 0);
	if (body->step_func_id == 0)
		return;	/* Step function not set. */
	world = body->world;
	
	lua_pushvalue(L, callfunc_index);
	assert(lua_isfunction(L, -1));		/* ... func */
	
	lua_pushinteger(L, body->step_func_id);	/* ... func_id */
	lua_pushboolean(L, 0);			/* ... func_id rm_bool=false */
	
	lua_pushlightuserdata(L, world);
	lua_pushlightuserdata(L, script_ptr);
	
	/* Call Lua step function. */
	/* Stack: ... __CallFunc func_id false worldPtr bodyPtr */
	if (lua_pcall(L, 4, 0, errfunc_index)) {
		log_err("[Lua] %s", lua_tostring(L, -1));
		abort();
	}
}

/*
 * Almost same thing as body_step(), only this one should be executed _after_
 * collision detection/response has been performed, and it runs Lua function
 * identified by [afterstep_func_id], rather thatn [step_func_id].
 */
void
body_afterstep(Body *body, lua_State *L, void *script_ptr)
{
	extern int errfunc_index;
	extern int callfunc_index;
	World *world;
	
	assert(body != NULL && body->afterstep_func_id >= 0);
	if (body->afterstep_func_id == 0)
		return;	/* Step function not set. */
	world = body->world;
	
	lua_pushvalue(L, callfunc_index);
	assert(lua_isfunction(L, -1));		/* ... func */
	
	lua_pushinteger(L, body->afterstep_func_id); /* ... func_id */
	lua_pushboolean(L, 0);			/* ... func_id rm_bool=false */
	
	lua_pushlightuserdata(L, world);
	lua_pushlightuserdata(L, script_ptr);
	
	/* Call Lua step function. */
	/* Stack: ... __CallFunc func_id false worldPtr bodyPtr */
	if (lua_pcall(L, 4, 0, errfunc_index)) {
		log_err("[Lua] %s", lua_tostring(L, -1));
		abort();
	}
}

/*
 * Remove all tiles and shapes (that belong to this body) from the quad tree,
 * then re-add them. Call this function whenever body's position changes.
 */
static void
body_update_tree(Body *body)
{
	Tile *tile;
	Shape *s;

	assert(body != NULL);
	
	/* Update tiles. */
	for (tile = body->tiles; tile != NULL; tile = tile->next) {
		if (!tile->go.stored)
			continue;	/* Tile is not in the tree. */
		
		/* If there are no sprites, we don't need to add/remove the
		   tile to/from quad tree. */
		if (tile->sprite_list == NULL ||
		    tile->sprite_list->num_frames == 0)
			continue;
		
		tile_update_tree(tile);
	}
	
	/* Update shapes. */
	for (s = body->shapes; s != NULL; s = s->next) {		
		shape_update_tree(s);
	}
}

/*
 * Change body's position.
 */
void
body_set_pos(Body *body, vect_f pos)
{
	assert(body != NULL);
	if (pos.x == body->pos.x && pos.y == body->pos.y)
		return;	/* Same position. */
	
	body->pos = pos;
	body_update_tree(body);
}

Timer *
body_add_timer(Body *body, double when, int func_id)
{
	int i;
	Timer *timer;

	assert(body != NULL && when >= 0.0 && func_id > 0);

	/* Find an unused timer slot. */
	for (i = 0; i < BODY_TIMERS_MAX; i++) {
		if (body->timers[i].func_id == 0)
			break;
	}
	assert(i != BODY_TIMERS_MAX);

	timer = &body->timers[i];
	timer->objtype = OBJTYPE_TIMER;
	timer->when = when;
	timer->func_id = func_id;
	timer->owner = body;
	timer->id = i;

	return timer;
}

void
body_run_timers(Body *body, lua_State *L)
{
	extern int eapi_index, errfunc_index;
	int i, run_i;
	double now;
	Timer runnable[BODY_TIMERS_MAX]; /* Space for a copy of body timers. */
	
	/* Current world time. */
	now = body->world->step * body->world->step_sec;
	
	/* Make a copy of the timers that must be run because if the body object
	   is destroyed during a timer call, further access to the original
	   array would be a mistake. */
	memset(runnable, 0, sizeof(Timer) * BODY_TIMERS_MAX);
	for (i = run_i = 0; i < BODY_TIMERS_MAX; i++) {
		if (body->timers[i].func_id == 0 || body->timers[i].when > now)
			continue;
		runnable[run_i++] = body->timers[i];	/* Copy. */

		/* Remove reference to timer from original array. */
		memset(&body->timers[i], 0, sizeof(Timer));
	}

	/* Execute runnable timers. */
	for (i = 0; runnable[i].func_id != 0 && i < BODY_TIMERS_MAX; i++) {
		lua_getfield(L, eapi_index, "__CallFunc");	/* ... func? */
		assert(lua_isfunction(L, -1));			/* ... func */
		
		lua_pushinteger(L, runnable[i].func_id);
		lua_pushboolean(L, 1);
		
		/* Call Lua timer function. */
		/* Stack: ... __CallFunc func_id true */
		if (lua_pcall(L, 2, 0, errfunc_index)) {
			log_err("[Lua] %s", lua_tostring(L, -1));
			abort();
		}
	}
}

