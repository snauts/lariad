#ifndef PHYSICS_H
#define PHYSICS_H

#include <lua.h>
#include "common.h"
#include "geometry.h"
#include "qtree.h"
#include "uthash.h"

struct Body_t;
struct World_t;

/* Shape types. */
#define SHAPE_CIRCLE	1
#define SHAPE_RECTANGLE	2

/* Shape flags. */
#define SHAPE_INTERSECT (1<<0)	/* Shape is intersecting with some other shape.
				   This is only used for debugging --
				   intersecting shapes are drawn in a different
				   color. */

/*
 * Shape represents a physical shape: either rectangle or circle.
 */
typedef struct Shape_t {
	int		objtype;	/* = OBJTYPE_SHAPE */
	struct Body_t	*body;		/* Body the shape belongs to. */

	int		shape_type;	/* Circle or rectangle. */
	union {
		BB rect;
		Circle circle;
	} shape;

	uint32_t	color;		/* Color for display in shape editor. */
	uint		flags;
	
	uint		group;		/* Collision group ID. */
	
	QTreeObject	go;		/* So shape can be added to quad tree.*/
	struct Shape_t *prev, *next;	/* For use in lists. */
} Shape;

typedef struct {
	int	objtype;	/* = OBJTYPE_TIMER */
	double	when;		/* When to run the timer (seconds since
				   world start). */
	int	func_id;	/* Function index into eapi.__idToObjectMap */

	void	*owner;		/* Object that owns the timer. */
	int	id;		/* Index into owner object's timer list. */
} Timer;

#define BODY_CHILDREN_MAX	100
#define BODY_TIMERS_MAX		10

#define BODY_SPECIAL	(1<<0)	/* Special bodies (Camera, Parallax, static) are
				   handled differently in some ways than the
				   regular bodies. One thing to note is that
				   they are not considered for collisions. */
#define BODY_SLEEP	(1<<1)	/* If set, it is OK for body to be inactive once
				   outside camera visibility. */

typedef struct Body_t {
	int		objtype;	/* = OBJTYPE_BODY */
	struct World_t *world;	/* World body belongs to. */

	vect_f		pos;		/* Current position. */
	int		cPhys;		/* Use physics from C code */
	vect_f		vel;		/* Velocity */
	vect_f		gravity;	/* Gravity */
	vect_f		prevstep_pos;	/* Position in the previous step. */
	vect_f		prevframe_pos;	/* Position in the previous frame. */
	
	uint		flags;

	struct Tile_t	*tiles;		/* List of tiles. */
	struct Shape_t	*shapes;	/* List of shapes. */

	struct Body_t	*parent;
	struct Body_t	*children[BODY_CHILDREN_MAX];
	
	/* Body step functions and timers are executed when the body is visible
	   (or close to being inside camera view). */
	int 		step_func_id;
	int		afterstep_func_id;
	Timer		timers[BODY_TIMERS_MAX];

	/* Linked list pointers (list head is "bodies" in World struct). */
	struct Body_t	*prev, *next;
	
	/* The below 2 members are used for adding Bodies to temporary hashes.*/
	struct Body_t *self;
	UT_hash_handle	hh;
} Body;

/* Shape routines. */
void	 shape_init(Shape *t);
Shape	*shape_new();
void	 shape_destroy(Shape *t);
void	 shape_free(Shape *t);
void	 shape_update_tree(Shape *s);

void	 body_init(Body *tb, struct World_t *world, vect_f pos, uint flags);
Body	*body_new(struct World_t *world, vect_f pos, uint flags);
void	 body_destroy(Body *tb);
void	 body_free(Body *tb);

void	 body_step(Body *tb, lua_State *L, void *script_ptr);
void	 body_afterstep(Body *tb, lua_State *L, void *script_ptr);
void	 body_set_pos(Body *tb, vect_f pos);
Timer	*body_add_timer(Body *body, double when, int func_id);
void	 body_run_timers(Body *body, lua_State *L);

#endif /* PHYSICS_H */
