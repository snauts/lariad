#include <SDL.h>
#include <assert.h>
#include <math.h>
#include "world.h"
#include "game2d.h"
#include "log.h"
#include "lua_util.h"
#include "utlist.h"

/* Collision distance defines how far, for a given shape [S], we look for other
   shapes that are possibly going to collide with [S]. One would think that you
   must not look further than shape [S] itself (i.e., collision distance zero),
   but this is not exactly how that works.
   See, it is possible (and common) for a shape to collide simultaneously with
   more than one other shape. After one collision (the one with higher priority)
   is resolved, we move on to the next shape. We don't want to look up
   intersecting shapes from tree every time (this is rather expensive), so
   instead we only consider shapes that we got the first time. To be more or
   less sure that we get all the shapes that matter, we look in an extended
   area that first time (not just within shape [S] bounding box). */
#define COLLISION_DISTANCE 5

/* Array used for iterating over bodies. */
#define MAX_ITER_BODIES 1000
static Body *iter_bodies[MAX_ITER_BODIES];
static uint num_iter_bodies = 0;
uint iter_body_count = 0;

/*
 * Remember current body positions.
 */
static void
save_prev_body_positions(World *world, int first_step)
{
	extern Camera *cameras[CAMERAS_MAX];
	uint i;
	Body *body;
	Parallax *px;
	
	/* Static body should not have moved. */
	assert(world->static_body.prevstep_pos.x == world->static_body.pos.x &&
	    world->static_body.prevstep_pos.y == world->static_body.pos.y);
	
	/* Save body positions. Do this only for the nearby bodies saved in
	   iter_bodies array. */
	for (i = 0; i < num_iter_bodies; i++) {
		body = iter_bodies[i];
		assert(body != NULL);	/* Bodies should not have been removed
					   at this point. */
		if (first_step)
			body->prevframe_pos = body->pos;
		body->prevstep_pos = body->pos;
	}

	/* Save positions of camera bodies. */
	for (i = 0; i < CAMERAS_MAX; i++) {
		if (cameras[i] == NULL || cameras[i]->body.world != world)
			continue;
		if (first_step)
			cameras[i]->body.prevframe_pos = cameras[i]->body.pos;
		cameras[i]->body.prevstep_pos = cameras[i]->body.pos;
	}
	
	/* Save positions of parallax bodies. */
	for (i = 0; i < WORLD_PX_PLANES_MAX; i++) {
		px = world->px_planes[i];
		if (px != NULL) {
			if (first_step)
				px->body.prevframe_pos = px->body.pos;
			px->body.prevstep_pos = px->body.pos;
		}
	}
}

static void
invoke_collision_handler(World *world, lua_State *L, Shape *A, Shape *B,
    BB *resolve, uint func_id)
{
	extern int errfunc_index;
	extern int callfunc_index;
	
	assert(func_id > 0);
	
	lua_pushvalue(L, callfunc_index);
	assert(lua_isfunction(L, -1));			/* ... func */
	
	lua_pushinteger(L, func_id);		/* ... func_id */
	lua_pushboolean(L, 0);			/* ... func_id rm_bool=false */
	
	/* Push world and both shape pointers. */
	lua_pushlightuserdata(L, world);
	lua_pushlightuserdata(L, A);
	lua_pushlightuserdata(L, B);
	
	/* Push the resolution info. */
	L_push_BB(L, resolve);
	
	/* Call Lua collision handler function. */
	/* Stack: ... __CallFunc func_id false worldPtr shapeA shapeB resolve */
	if (lua_pcall(L, 6, 0, errfunc_index)) {
		log_err("[Lua] %s", lua_tostring(L, -1));
		abort();
	}
}

/*
 * When two colliding shapes are found, the below structure is filled and stored
 * in an array. Once all collisions for a particular shape are found and stored
 * in this way, they are sorted by priority. Then we iterate over thes sorted
 * array and execute each handler.
 */
typedef struct {
	uint	func_id;
	int	priority;
	Shape	*shape_A, *shape_B;
	uint32_t group_A, group_B;
} Collision;

static void
handle_shape_collisions(World *world, Shape *s, Collision *collision_array,
    uint max_collisions, uint *num_collisions)
{
	int stat;
	uint i, num_shapes;
	BB exp_shape_bb;
#define MAX_SHAPES 500
	QTreeObject *intersect_maybe[MAX_SHAPES];
	Handler *handler;
	Shape *other_s;
	Collision *col;
	
	assert(s != NULL && s->group != 0);
	
	/* Expand shape bounding box. We want to get all nearby shapes within
	   COLLISION_DISTANCE. */
	bb_init(&exp_shape_bb, s->go.bb.l - COLLISION_DISTANCE,
	    s->go.bb.b - COLLISION_DISTANCE, s->go.bb.r + COLLISION_DISTANCE,
	    s->go.bb.t + COLLISION_DISTANCE);
	    
	/* Get a list of shapes that this one potentially intersects. */
	stat = qtree_lookup(&world->shape_tree, &exp_shape_bb, intersect_maybe,
	    MAX_SHAPES, &num_shapes);
#ifndef NDEBUG
	if (stat != 0) {
		log_err("Too many shapes considered for collision.");
		abort();
	}
#endif
	
	/* Now iterate over shapes that we found can potentially intersect with
	   shape [s]. As we do this, we keep filling an array of Collision
	   structs. If the shapes have a collision handler registered for them,
	   then an entry is created in this array. */
	for (i = 0; i < num_shapes; i++) {
		other_s = intersect_maybe[i]->ptr;
		assert(other_s->objtype == OBJTYPE_SHAPE);
		assert(other_s->group != 0);
		if (s->body == other_s->body)
			continue;	/* Skip shapes with the same body. */
		
		/* Find if there's a collision routine registered for these
		   shapes. */
		handler = &world->collision_map[s->group][other_s->group];
		if (handler->func_id != 0) {
			assert(*num_collisions < max_collisions);
			col = &collision_array[(*num_collisions)++];
			col->func_id = handler->func_id;
			col->priority = handler->priority;
			col->shape_A = s;
			col->shape_B = other_s;
			col->group_A = s->group;
			col->group_B = other_s->group;
		}
	
		/* Switch order of shapes, and look for registered handler
		   again. */
		handler = &world->collision_map[other_s->group][s->group];
		if (handler->func_id != 0) {
			assert(*num_collisions < max_collisions);
			col = &collision_array[(*num_collisions)++];
			col->func_id = handler->func_id;
			col->priority = handler->priority;
			col->shape_A = other_s;
			col->shape_B = s;
			col->group_A = other_s->group;
			col->group_B = s->group;
		}
	}
}

#ifndef NDEBUG
/*
 * Unset SHAPE_INTERSECT flag for every nearby shape. Used for debugging only.
 */
static void
unset_intersect_flag(World *world)
{
	extern Camera *cameras[CAMERAS_MAX];
	Parallax *px;
	Body *body;
	Shape *s;
	uint i;
	
	/* Remove intersection flag from all shapes. */
	for (s = world->static_body.shapes; s != NULL; s = s->next)
		s->flags &= ~SHAPE_INTERSECT;
	for (i = 0; i < CAMERAS_MAX; i++) {
		if (cameras[i] == NULL || cameras[i]->body.world != world)
			continue;
		for (s = cameras[i]->body.shapes; s != NULL; s = s->next)
			s->flags &= ~SHAPE_INTERSECT;
	}
	for (i = 0; i < WORLD_PX_PLANES_MAX; i++) {
		px = world->px_planes[i];
		if (px != NULL)
			for (s = px->body.shapes; s != NULL; s = s->next)
				s->flags &= ~SHAPE_INTERSECT;
	}
	for (i = 0; i < num_iter_bodies; i++) {
		body = iter_bodies[i];
		if (body == NULL)
			continue;	/* Body was Destroy()ed. */
		for (s = body->shapes; s != NULL; s = s->next)
			s->flags &= ~SHAPE_INTERSECT;
	}
}
#endif

/*
 * Comparison function used by qsort(). Compares Collision struct priorities in
 * such a way that those Collisions with higher priority end up in the beginning
 * of the array.
 * Also note that in cases where priorities are equal, the two collision structs
 * are compared by their shape pointers. It is done in this way so we could
 * later (while iterating over the array) identify and discard duplicate
 * collision structs.
 */
static inline int
collision_priority_cmp(const void *a, const void *b)
{
	const Collision *ca = a;
	const Collision *cb = b;
		
	if (ca->priority == cb->priority) {
		if (ca->shape_A == cb->shape_A) {
			if (ca->shape_B == cb->shape_B)
				return 0;
			return (ca->shape_B < cb->shape_B) ? 1 : -1;
		}
		return (ca->shape_A < cb->shape_A) ? 1 : -1;
	}
	return (ca->priority < cb->priority) ? 1 : -1;
}

/*
 * Go through all shapes that belong to dynamic bodies (bodies whose position
 * could have changed during step function calls) and execute collision handlers
 * for those shapes that intersect.
 */
static void
resolve_collisions(World *world, lua_State *L)
{
	BB resolve;
	Shape *s, *shape_A, *shape_B;
	uint i, num_collisions;
#define MAX_COLLISIONS 2000
	Collision collision_array[MAX_COLLISIONS], *col;
	
#ifndef NDEBUG
	unset_intersect_flag(world);
#endif
	/* Prepare collision structs for each body in the array. */
	num_collisions = 0;
	for (i = 0; i < num_iter_bodies; i++) {
		if (iter_bodies[i] == NULL)
			continue;	/* Body was Destroy()ed. */

		/* Consider each shape. */
		for (s = iter_bodies[i]->shapes; s != NULL; s = s->next) {
			handle_shape_collisions(world, s, collision_array,
			    MAX_COLLISIONS, &num_collisions);
		}
	}
	
	/* Sort collisions by priority. Then iterate over them and execute their
	   handler functions. */
	qsort(collision_array, num_collisions, sizeof(Collision),
	    collision_priority_cmp);
	Shape *prev_shape_A = NULL;
	Shape *prev_shape_B = NULL;
	for (i = 0; i < num_collisions; i++) {
		col = &collision_array[i];
		shape_A = col->shape_A;
		shape_B = col->shape_B;
		if (prev_shape_A == shape_A && prev_shape_B == shape_B)
			continue;	/* Duplicate collision! */
		if (shape_A->objtype != OBJTYPE_SHAPE ||
		    shape_B->objtype != OBJTYPE_SHAPE)
			continue;	/* Destroyed shapes. */
		
		/* It is possible (if unlikely) that a shape was destroyed, and
		   then some other shape reused its memory. Here we make sure
		   that the shape that's currently there belongs to this world
		   and collision group is the same as before. So even if it is
		   a different shape, at least it's kind of like the old one. */
		if (shape_A->body->world != world ||
		    shape_B->body->world != world ||
		    shape_A->group != col->group_A ||
		    shape_B->group != col->group_B)
			continue;
		
		/* Save shape pointers, so we can check for duplicates. */
		prev_shape_A = shape_A;
		prev_shape_B = shape_B;
		
		/* Compute resolution box and invoke handler. */
		if (bb_intersect_resolve(&shape_B->go.bb, &shape_A->go.bb, &resolve)) {
#ifndef NDEBUG
			/* Mark shapes as intersecting. This means they
			   will be drawn in a different color than the
			   rest. */
			shape_A->flags |= SHAPE_INTERSECT;
			shape_B->flags |= SHAPE_INTERSECT;
#endif
			invoke_collision_handler(world, L, shape_A, shape_B,
			    &resolve, col->func_id);
		}
	}
}

/*
 * Initialize world.
 *
 * world		World about to be intialized.
 * step_ms		World step duration in milliseconds.
 * tree_depth		Depth of the quad trees that partition space.
 */
static void
world_init(World *world, const char *name, uint step_ms, uint tree_depth)
{
	extern uint64_t game_time;
	
	assert(world != NULL);
	assert(name != NULL && strlen(name) < WORLD_NAME_LENGTH);
	assert(step_ms > 0 && step_ms < 1000);

	world->objtype = OBJTYPE_WORLD;
	strcpy(world->name, name);
	world->step = 0;
	world->paused = 0;
	world->next_step_time = game_time;
	world->step_ms = step_ms;
	world->step_sec = (double)step_ms / 1000.0;
	world->killme = 0;
	world->virgin = 1;
	
	world->next_group_id = 1;
	world->groups = NULL;
	memset(world->collision_map, 0,
	    WORLD_HANDLERS_MAX * WORLD_HANDLERS_MAX * sizeof(Handler));

	memset(world->bg_color, 0, sizeof(float) * 4);
	memset(world->timers, 0, sizeof(Timer) * WORLD_TIMERS_MAX);
	memset(world->px_planes, 0, sizeof(Parallax *) * WORLD_PX_PLANES_MAX);
	world->bodies = NULL;

	/* Set up tile & shape quad trees. */
	qtree_init(&world->tile_tree, tree_depth);
	qtree_init(&world->shape_tree, tree_depth);

	/* Init static body. */
	body_init(&world->static_body, world, vect_f_zero, BODY_SPECIAL);
}

/*
 * Create a new world and return its pointer. For argument descriptions
 * see world_init().
 */
World *
world_new(const char *name, uint step_ms, uint tree_depth)
{
	extern mem_pool mp_world;
	World *world;

	world = mp_alloc(&mp_world);
	log_msg("Create world '%s' (%p).", name, world);
	world_init(world, name, step_ms, tree_depth);
	return world;
}

/*
 * Clear out world and free any memory that it owns (but not the world
 * structure itself).
 */
static void
world_destroy(World *world)
{
	log_msg("Destroy world '%s' (%p).", world->name, world);
	
	world->killme = 1;
	world_clear(world);

	body_destroy(&world->static_body);
	qtree_destroy(&world->tile_tree);
	qtree_destroy(&world->shape_tree);

	memset(world, 0, sizeof(World));
}

/*
 * Add body to world. Bodies that have the BODY_SPECIAL flag set, do not go into
 * the regular body list.
 */
void
world_add_body(World *world, Body *body)
{
	assert(world != NULL && body != NULL);

	/* Special bodies (Camera, Parallax, static) are not added to the
	   list. */
	if (body->flags & BODY_SPECIAL)
		return;
	DL_APPEND(world->bodies, body);	/* Add to world's body list. */
}

/*
 * Remove body from world.
 */
void
world_remove_body(World *world, Body *body)
{
	uint i;
	
	/* Special bodies (camera, parallax, static) were not added to body
	   list, so no need to remove them. */
   	assert(world != NULL && body != NULL);
	if (body->flags & BODY_SPECIAL)
		return;

	assert(world->bodies != NULL);
	DL_DELETE(world->bodies, body);	/* Remove from body list. */
	
	/* Remove from current iteration array if it's there. */
	assert(num_iter_bodies <= MAX_ITER_BODIES);
	for (i = 0; i < num_iter_bodies; i++) {
		if (iter_bodies[i] == body)
			iter_bodies[i] = NULL;
	}
}

/*
 * Destroy world and free its memory.
 */
void
world_free(World *world)
{
	extern mem_pool mp_world;
	world_destroy(world);
	mp_free(&mp_world, world);
}

/*
 * Destroy owned non-static bodies, parallax planes, and timers, and everything
 * else.
 */
void
world_clear(World *world)
{
	int i;
	extern Camera *cameras[CAMERAS_MAX];
	extern mem_pool mp_group;
	Group *group;
	
	assert(world != NULL);

	/* Free parallax planes. */
	for (i = 0; i < WORLD_PX_PLANES_MAX; i++) {
		if (world->px_planes[i] == NULL)
			continue;
		parallax_free(world->px_planes[i]);
		world->px_planes[i] = NULL;
	}

	/* Free owned bodies. */
	while (world->bodies != NULL)
		body_free(world->bodies);

	/* Free tiles and shapes owned by world's static body. */
	while (world->static_body.tiles != NULL)
		tile_free(world->static_body.tiles);
	while (world->static_body.shapes != NULL)
		shape_free(world->static_body.shapes);

	/* Clear timers. */
	memset(world->timers, 0, sizeof(Timer) * WORLD_TIMERS_MAX);

	/* Clear out any cameras that are "filming" this world. */
	for (i = 0; i < CAMERAS_MAX; i++) {
		if (cameras[i] == NULL || cameras[i]->body.world != world)
			continue;
		cam_free(cameras[i]);
		cameras[i] = NULL;
	}
	
	/* Clear group hash. */
	while (world->groups) {
		group = world->groups;
		HASH_DEL(world->groups, group);
		mp_free(&mp_group, group);
	}
	world->next_group_id = 1;	/* Reset ID counter. */
	
	/* Clear collision handler map. */
	memset(world->collision_map, 0,
	    WORLD_HANDLERS_MAX * WORLD_HANDLERS_MAX * sizeof(Handler));
}

/*
 * Add a timer to world.
 *
 * world	World that you want to add the timer to.
 * when		When is this timer supposed to run (seconds since world
 *		start).
 * func_id	Function ID to invoke once it's time.
 *
 * Returns pointer to Timer structure.
 */
Timer *
world_add_timer(World *world, double when, uint func_id)
{
	int i;
	Timer *timer;

	assert(world != NULL && when >= 0.0 && func_id > 0);

	/* Find an unused timer slot. */
	for (i = 0; i < WORLD_TIMERS_MAX; i++) {
		if (world->timers[i].func_id == 0)
			break;
	}
	assert(i != WORLD_TIMERS_MAX);

	timer = &world->timers[i];
	timer->objtype = OBJTYPE_TIMER;
	timer->when = when;
	timer->func_id = func_id;
	timer->owner = world;
	timer->id = i;

	return timer;
}

static void
run_timers(World *world, lua_State *L)
{
	extern int callfunc_index, errfunc_index;
	extern Camera *cameras[CAMERAS_MAX];
	uint i, func_id;
	double now;

	assert(world != NULL);
	now = world->step * world->step_sec;	/* Current world time. */

	/* Run world timers. */
	for (i = 0; i < WORLD_TIMERS_MAX; i++) {
		if (world->timers[i].func_id == 0)
			continue;	/* Empty slot. */
		if (world->timers[i].when > now)
			continue;	/* Timer scheduled for later time. */

		/* Extract timer function ID, and remove timer from list. */
		func_id = world->timers[i].func_id;
		world->timers[i].func_id = 0;
		
		/* Execute timer. */
		lua_pushvalue(L, callfunc_index);
		assert(lua_isfunction(L, -1));		/* ... func */
		lua_pushinteger(L, func_id);
		lua_pushboolean(L, 1);
		/* Call Lua timer function. */
		/* Stack: ... __CallFunc func_id true */
		if (lua_pcall(L, 2, 0, errfunc_index)) {
			log_err("[Lua] %s", lua_tostring(L, -1));
			abort();
		}
	}
	
	/* Run timers for static body. */
	body_run_timers(&world->static_body, L);
		
	/* Invoke timer functions for each body in the array. */
	for (i = 0; i < num_iter_bodies; i++) {
		if (iter_bodies[i] == NULL)
			continue;	/* Body was Destroy()ed. */
		body_run_timers(iter_bodies[i], L);
	}
	
	/* Run parallax timers. */
	for (i = 0; i < WORLD_PX_PLANES_MAX; i++) {
		if (world->px_planes[i] != NULL)
			body_run_timers(&world->px_planes[i]->body, L);
	}
	
	/* Run camera timers. */
	for (i = 0; i < CAMERAS_MAX; i++) {
		if (cameras[i] != NULL && cameras[i]->body.world == world)
			body_run_timers(&cameras[i]->body, L);
	}
}

static void
step_bodies(World *world, lua_State *L, int afterstep)
{
	extern Camera *cameras[CAMERAS_MAX];
	uint i;
	Parallax *px;
	void (*step_func)(Body *, lua_State *, void *);
	
	/* Choose body_step or body_afterstep function. */
	step_func = afterstep ? body_afterstep : body_step;

	/* Step static body. */
	step_func(&world->static_body, L, &world->static_body);
		
	/* Invoke body step (after-step) function for each body in the array. */
	for (i = 0; i < num_iter_bodies; i++) {
		if (iter_bodies[i] == NULL)
			continue;	/* Body was Destroy()ed. */
		step_func(iter_bodies[i], L, iter_bodies[i]);
	}
	
	/* Step parallax bodies. */
	for (i = 0; i < WORLD_PX_PLANES_MAX; i++) {
		px = world->px_planes[i]; 
		if (px != NULL)
			step_func(&px->body, L, px);
	}
	
	/* Step camera bodies. */
	for (i = 0; i < CAMERAS_MAX; i++) {
		if (cameras[i] != NULL && cameras[i]->body.world == world)
			step_func(&cameras[i]->body, L, cameras[i]);
	}
}

/*
 * Execute body step functions and timers, then resolve collision (call
 * registered collision handlers), then execute after-step functions.
 *
 * world		World that will be stepped.
 * L		Lua state pointer.
 * first_step	Whether this is the first step of a frame. Necessary when
 *		saving object positions. Bodies have the property prevframe_pos,
 *		which is their position in the previous frame. We want to
 *		overwrite this only in the first step of a frame, and not every
 *		step.
 */
void
world_step(World *world, lua_State *L, int first_step)
{
	extern Camera *cameras[CAMERAS_MAX];
	struct {
		vect_f pos;
		vect_i size;
	} cam_data[CAMERAS_MAX];
	Body *body;
	Camera *cam;
	uint cam_i, num_cam_data;
	vect_f diff;
	
	/* Shouldn't be a dying world. */
	assert(world != NULL && !world->killme);
	
	/* Prepare an array with camera data (position and size) for this
	   world. */
	num_cam_data = 0;
	for (cam_i = 0; cam_i < CAMERAS_MAX; cam_i++) {
		cam = cameras[cam_i];
		if (cam == NULL || cam->body.world != world)
			continue;
		cam_data[num_cam_data].pos = cam->body.pos;
		cam_data[num_cam_data].size.x = cam->size.x * 1.5;
		cam_data[num_cam_data].size.y = cam->size.y * 1.5;
		num_cam_data++;
	}
	
	/*
	 * Create a global array of bodies that functions below will iterate
	 * over and execute timers, step functions, etc.
	 *
	 * Ignore bodies that are far away from any cameras and have their
	 * SLEEP flag set.
	 */
	num_iter_bodies = 0;
	for (body = world->bodies; body != NULL; body = body->next) {
		if (!(body->flags & BODY_SLEEP)) {
			/* Body must not sleep. Put it in the array. */
			assert(num_iter_bodies < MAX_ITER_BODIES);
			iter_bodies[num_iter_bodies++] = body;
			continue;
		}
		for (cam_i = 0; cam_i < num_cam_data; cam_i++) {
			/* Put body in the array if it's close to camera. */
			diff = vect_f_sub(body->pos, cam_data[cam_i].pos);
			if (abs(diff.x) < cam_data[cam_i].size.x &&
			    abs(diff.y) < cam_data[cam_i].size.y) {
				assert(num_iter_bodies < MAX_ITER_BODIES);
				iter_bodies[num_iter_bodies++] = body;
				break;	/* Once is enough. */
			}
		}
	}
	iter_body_count = num_iter_bodies;
	
	save_prev_body_positions(world, first_step);
	
	/* Execute timers and step functions. */
	run_timers(world, L);
	step_bodies(world, L, 0);
	
	/* Now that body positions have possibly changed, resolve collisions. */
	resolve_collisions(world, L);
	
	/* Call after-step functions. */
	step_bodies(world, L, 1);

	/* Advance world step number. */
	world->step++;
}
