#ifndef WORLD_H
#define WORLD_H

#include <lua.h>
#include "common.h"
#include "qtree.h"
#include "physics.h"
#include "str.h"

#define WORLD_TIMERS_MAX	5
#define WORLD_PX_PLANES_MAX	300
#define WORLD_HANDLERS_MAX	200
#define WORLD_NAME_LENGTH	50
#define WORLD_GROUPNAME_LENGTH	50

/*
 * Map hashes of collision group names to their full name strings and ID
 * numbers:
 * 	hash("GroupName") -> {"GroupName", groupID}.
 * Shapes have only group IDs stored within their structs.
 *
 * This hash is used to find existing groups when only the group name is known.
 *
 * If ever it is necessary to find a group given its ID, iterate linearly over
 * the hash and compare IDs (e.g, this is done in eapi.Dump).
 */
typedef struct {
	char	name[WORLD_GROUPNAME_LENGTH];	/* Name of collision group. */
	uint	id;				/* Group ID. */
	UT_hash_handle	hh;
} Group;

/*
 * Collision handler struct.
 */
typedef struct {
	uint		func_id;	/* Collision handler function ID. */
	int		priority;	/* Handler priority determines order in
					   which handlers are executed when
					   shape intersects with more than one
					   other shape simultaneously. */
} Handler;

/*
 * World struct describes a physical world instance.
 */
typedef struct World_t {
	int	objtype;	/* = OBJTYPE_WORLD */
	char	name[WORLD_NAME_LENGTH]; /* World name (optional). */
	float	bg_color[4];	/* Background color. */

	uint	step;		/* Current world step (step counter). */
	uint	step_ms;	/* Duration of one step in milliseconds. */
	double	step_sec;	/* Duration of one step in seconds. */
	uint64_t next_step_time;
	int	paused;		/* Is world paused? */
	
	Body	static_body;	/* Body for all static shapes. */
	Body	*bodies;	/* List of all bodies within world. */

	QTree	tile_tree;	/* Quad tree for tiles. */
	QTree	shape_tree;	/* Quad tree for shapes. */
	Timer	timers[WORLD_TIMERS_MAX];
	struct Parallax_t *px_planes[WORLD_PX_PLANES_MAX]; /* Parallax planes.*/
	
	uint	next_group_id;	/* Collision groups are given consecutive IDs.*/
	Group	*groups;	/* Map collision group name hashes to group
				   name and ID. */
	/* Map pairs of collision group IDs to their collision handler. */
	Handler collision_map[WORLD_HANDLERS_MAX][WORLD_HANDLERS_MAX];

	int	killme;		/* If true, world should be freed as soon
				   as possible. */
	int	virgin;		/* If true, the world has only been
				   recently created, and world_step() must be
				   called on it before the world is
				   rendered. */
} World;

World	*world_new(const char *name, uint step_ms, uint tree_depth);
void	 world_free(World *world);
void	 world_clear(World *world);
void	 world_step(World *world, lua_State *L, int first_step);

Timer	*world_add_timer(World *world, double when, uint func_id);
void	 world_add_body(World *world, Body *body);
void	 world_remove_body(World *world, Body *body);

#endif /* WORLD_H */
