#include <assert.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include "qtree.h"
#include "log.h"
#include "mem.h"
#include "physics.h"
#include "world.h"
#include "utlist.h"

vect_f_list *
listvect_new(vect_f v)
{
	extern mem_pool mp_listvect;
	vect_f_list *lv;
	
	lv = mp_alloc(&mp_listvect);
	lv->v = v;
	return lv;
}

void
listvect_free(vect_f_list *v)
{
	extern mem_pool mp_listvect;
	mp_free(&mp_listvect, v);
}

Shape *
shape_new()
{
	extern mem_pool mp_shape;
	Shape *shape;
	
	shape = mp_alloc(&mp_shape);
	shape_init(shape);
	return shape;
}

void
shape_init(Shape *s)
{
	assert(s != NULL);

	s->objtype = OBJTYPE_SHAPE;
	s->shape_type = 0;
	memset(&s->shape, 0, sizeof(s->shape));
	s->body = NULL;
	s->color = 0;
	s->flags = 0;
	s->prev = s->next = NULL;
	qtree_obj_init(&s->go, s);		/* Ready for quad tree. */
}

void
shape_destroy(Shape *s)
{
	Body *body;
	QTree *tree;
	
	assert(s != NULL && s->shape_type != 0);
	body = s->body;
	assert(body != NULL && body->objtype == OBJTYPE_BODY);

	/* Remove from tree if it's in there. */
	if (s->go.stored) {
		tree = &body->world->shape_tree;
		qtree_remove(tree, &s->go);
	}

	/* Remove shape from its body's list if it was added. */
	if (s->prev != NULL || s->next != NULL) {
		assert(body->shapes != NULL);
		DL_DELETE(body->shapes, s);
	}
	
	memset(s, 0, sizeof(Shape));
}

void
shape_free(Shape *shape)
{
	extern mem_pool mp_shape;
	shape_destroy(shape);
	mp_free(&mp_shape, shape);
}

void
shape_update_tree(Shape *s)
{
	BB *bb;
	Body *body;
	
	/* Shorthand. */
	body = s->body;
	
	/* Re-add to quad tree. */
	bb = &s->go.bb;
	switch (s->shape_type) {
	case SHAPE_CIRCLE:
		bb->l = s->shape.circle.offset.x - s->shape.circle.radius +
		    round(body->pos.x);
		bb->b = s->shape.circle.offset.y - s->shape.circle.radius +
		    round(body->pos.y);
		bb->r = bb->l + s->shape.circle.radius * 2;
		bb->t = bb->b + s->shape.circle.radius * 2;
		break;
	case SHAPE_RECTANGLE:
		bb->l = s->shape.rect.l + round(body->pos.x);
		bb->b = s->shape.rect.b + round(body->pos.y);
		bb->r = s->shape.rect.r + round(body->pos.x);
		bb->t = s->shape.rect.t + round(body->pos.y);
		break;
	default:
		log_err("Invalid shape type (%i).", s->shape_type);
		abort();
	}
	qtree_update(&body->world->shape_tree, &s->go);
}
