#include <SDL_opengl.h>
#include <assert.h>
#include <math.h>
#include <stdlib.h>
#include "config.h"
#include "console.h"
#include "draw.h"
#include "game2d.h"
#include "log.h"
#include "misc.h"
#include "physics.h"
#include "matrix.h"
#include "world.h"

uint bound_texture = (uint) -1;
static uint blend_func = 0;

/*
 * Depth comparison routine to use with qsort(). Into the screen is the negative
 * direction, out of the screen -- positive. We want tiles sorted back to front.
 */
static int
tile_depth_cmp(const void *a, const void *b)
{
	float a_depth, b_depth;
	Tile *a_tile, *b_tile;
	GLuint a_texid, b_texid;

	a_tile = (*(QTreeObject **)a)->ptr;
	b_tile = (*(QTreeObject **)b)->ptr;

	assert(a != NULL && b != NULL);
	assert(a_tile != b_tile);
	assert(a_tile != NULL && a_tile->objtype == OBJTYPE_TILE);
	assert(b_tile != NULL && b_tile->objtype == OBJTYPE_TILE);

	a_depth = a_tile->depth;
	b_depth = b_tile->depth;

	/* If the depth values of both tiles are the same, compare their
	   pointers. This will ensure that overlapping tiles with equal depth
	   will not flicker due to differing implementations of qsort() or other
	   factors. */
	if (a_depth == b_depth) {
		a_texid = a_tile->sprite_list->tex->id;
		b_texid = b_tile->sprite_list->tex->id;
		if (a_texid == b_texid)
			return (a_tile < b_tile) ? -1 : 1;
		return a_texid < b_texid ? -1 : 1;
	}

	return (a_depth < b_depth) ? -1 : 1;
}

static void
draw_visible_tiles(Camera *cam, World *world, BB *visible_area)
{
	int stat;
	uint i, num_tiles;
	Tile *tile;
	static QTreeObject *visible_tiles[TILES_MAX];

	/* Look up visible tiles. */
	stat = qtree_lookup(&world->tile_tree, visible_area, visible_tiles,
	    TILES_MAX, &num_tiles);
#ifndef NDEBUG
	if (stat != 0) {
		log_err("Too many visible tiles.");
		abort();
	}
#endif

	/* Add camera tiles to the list, since those are always visible and not
	   in quad tree. */
	for (tile = cam->body.tiles; tile != NULL; tile = tile->next) {
		assert(num_tiles < TILES_MAX);
		visible_tiles[num_tiles++] = &tile->go;
	}

	/* Update parallax tiles and add them to lookup hash as well. */
	for (i = 0; i < WORLD_PX_PLANES_MAX; i++) {
		if (world->px_planes[i] == NULL)
			continue;
		parallax_update(world->px_planes[i], cam);
		for (tile = world->px_planes[i]->body.tiles; tile != NULL;
		    tile = tile->next) {
			assert(num_tiles < TILES_MAX);
			visible_tiles[num_tiles++] = &tile->go;
		}
	}

	/* Sort tiles by depth, so drawing happens back to front. */
	qsort(visible_tiles, num_tiles, sizeof(QTreeObject *), tile_depth_cmp);

	for (i = 0; i < num_tiles; i++) {
		tile = visible_tiles[i]->ptr;
		assert(tile->objtype == OBJTYPE_TILE);

		/* The tile should not have been added to tree if it has no
		   sprites. */
		assert(tile->sprite_list != NULL && tile->sprite_list->num_frames > 0);

		draw_tile(cam, tile);
	}
}

static void
draw_visible_shapes(const World *world, const BB *visible_area)
{
	int stat;
	uint i, num_shapes;
	Shape *s;
#define MAX_SHAPES 5000
	QTreeObject *visible_shapes[MAX_SHAPES];

	/* Look up visible shapes. */
	stat = qtree_lookup(&world->shape_tree, visible_area, visible_shapes,
	    MAX_SHAPES, &num_shapes);
#ifndef NDEBUG
	if (stat != 0) {
		log_err("Too many visible shapes.");
		abort();
	}
#endif

	/* Draw visible shapes. */
	glLineWidth(2.0);
	glDisable(GL_TEXTURE_2D);
	for (i = 0; i < num_shapes; i++) {
		s = visible_shapes[i]->ptr;
		assert(s->objtype == OBJTYPE_SHAPE);
		draw_shape(s);
	}
	glEnable(GL_TEXTURE_2D);
}

void
draw(Camera *cam)
{
	Matrix m;
	Body *bp;
	BB visible_area;
	vect_i visible_size, visible_halfsize;
	World *world;
	extern int drawShapes, drawTileTree, drawShapeTree, outsideView;

	/* Camera should be bound to exactly one world (the one its body
	   belongs to. */
	world = cam->body.world;
	assert(world != NULL);

	/* Camera viewport. */
	glViewport(cam->viewport.l, cam->viewport.t,
	    cam->viewport.r - cam->viewport.l,	/* width */
	    cam->viewport.b - cam->viewport.t);	/* height */

	/* Visible area projection. */
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	visible_size.x = round(cam->size.x/cam->zoom);
	visible_size.y = round(cam->size.y/cam->zoom);
	visible_halfsize.x = visible_size.x/2;
	visible_halfsize.y = visible_size.y/2;
	if (!outsideView)
		glOrtho(-visible_halfsize.x, visible_halfsize.x,
		    -visible_halfsize.y, visible_halfsize.y, 0.0, 1.0);
	else
		glOrtho(-visible_size.x, +visible_size.x,
		    -visible_size.y, +visible_size.y, 0.0, 1.0);
	glMatrixMode(GL_MODELVIEW);

	/* Visible area bounding box. */
	bb_init(&visible_area,
		round(cam->body.pos.x) - visible_halfsize.x,
		round(cam->body.pos.y) - visible_halfsize.y,
		round(cam->body.pos.x) + visible_halfsize.x,
		round(cam->body.pos.y) + visible_halfsize.y);

	/* Draw background-color quad. */
	if (world->bg_color[3] > 0.0)	/* If visible (alpha > 0) */
		draw_quad(cam, &visible_area, world->bg_color);

	draw_visible_tiles(cam, world, &visible_area);

	/* Set modelview matrix according to camera. Since we do this, the
	   following drawing functions do not take camera position into account.
	   The transformation is done by OpenGL automatically.

	   When drawing tiles (see code above), however, we consider camera
	   position because we must draw them pixel-accurate (body/camera
	   positions are rounded). The stuff below is just for debugging so
	   we don't really care. */
	cam_view(cam, &m);
	glLoadMatrixf(m.val);

	if (drawShapes) {
		/* Draw axes and all visible shapes. */
		draw_axes();
		draw_visible_shapes(world, &visible_area);

		/* Draw points at body positions. */
		for (bp = world->bodies; bp != NULL; bp = bp->next)
			draw_point(bp->pos);
		draw_point(world->static_body.pos);
	}
	if (drawTileTree)
		draw_qtree(&world->tile_tree);
	if (drawShapeTree)
		draw_qtree(&world->shape_tree);
	glLoadIdentity();
}

static inline void draw_sprite(Tile *tile, const Camera *cam) {
	TexFrag texfrag;
	vect_f BL, BR, TR, TL;

	SpriteList *sprite_list = tile->sprite_list;

	vect_i size = tile->size;
	vect_i rel_pos = tile->pos;

	vect_f obj_pos = vect_f_round(tile->body->pos);
	vect_f obj_prevpos = vect_f_round(tile->body->prevframe_pos);
	vect_f cam_prevpos = vect_f_round(cam->body.prevframe_pos);
		    
	assert(sprite_list != NULL);
	assert(sprite_list->frames != NULL
	       && sprite_list->num_frames > 0
	       && tile->frame_index < sprite_list->num_frames);
	assert((size.x > 0.0 && size.y > 0.0) 
	    || (size.x < 0.0 && size.y < 0.0));

	/* Switch texture and blending function if necessary. */
	if (bound_texture != sprite_list->tex->id ||
	    blend_func != (tile->flags & TILE_MULTIPLY)) {

		/* Switch texture if it differs from currently selected one. */
		if (bound_texture != sprite_list->tex->id) {
			glBindTexture(GL_TEXTURE_2D, sprite_list->tex->id);
			bound_texture = sprite_list->tex->id;
		}
		
		/* Switch blending if it differs from the current one. */
		if (blend_func != (tile->flags & TILE_MULTIPLY)) {
			if (tile->flags & TILE_MULTIPLY) {
				glBlendFunc(GL_ZERO, GL_SRC_COLOR);
			} else {
				glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
			}
			blend_func = (tile->flags & TILE_MULTIPLY);
		}
	}

	texfrag = sprite_list->frames[tile->frame_index];
	assert(texfrag.r > texfrag.l && texfrag.b > texfrag.t);

	if (size.x < 0.0) { /* If size is negative, use sprite size. */
		size.x = round((texfrag.r - texfrag.l)*sprite_list->tex->pow_w);
		size.y = round((texfrag.b - texfrag.t)*sprite_list->tex->pow_h);
	}

	/* Subtract camera position from object position. */
	obj_pos = vect_f_sub(obj_pos, vect_f_round(cam->body.pos));
	obj_prevpos = vect_f_sub(obj_prevpos, cam_prevpos);

	/* Corner positions. */
	BL = vect_f_new(rel_pos.x, rel_pos.y);
	BR = vect_f_new(rel_pos.x + size.x, rel_pos.y);
	TR = vect_f_new(rel_pos.x + size.x, rel_pos.y + size.y);
	TL = vect_f_new(rel_pos.x, rel_pos.y + size.y);

	if (tile->angle != 0.0) {
	    BL = vect_f_rotate(&BL, tile->angle);
	    BR = vect_f_rotate(&BR, tile->angle);
	    TR = vect_f_rotate(&TR, tile->angle);
	    TL = vect_f_rotate(&TL, tile->angle);
	}

	/* Translate to object position. */
	BL = vect_f_add(BL, obj_pos);
	BR = vect_f_add(BR, obj_pos);
	TR = vect_f_add(TR, obj_pos);
	TL = vect_f_add(TL, obj_pos);

	GLfloat colors[] = {
		tile->color[0], tile->color[1], tile->color[2], tile->color[3],
		tile->color[0], tile->color[1], tile->color[2], tile->color[3],
		tile->color[0], tile->color[1], tile->color[2], tile->color[3],
		tile->color[0], tile->color[1], tile->color[2], tile->color[3],
	};
	glColorPointer(4, GL_FLOAT, 0, colors);

	GLfloat vertices[] = {
		BL.x, BL.y,
		BR.x, BR.y,
		TR.x, TR.y,
		TL.x, TL.y,
	};
	glVertexPointer(2, GL_FLOAT, 0, vertices);

	if (tile->flags & TILE_FLIP_X) {
		if (tile->flags & TILE_FLIP_Y) {
			GLfloat texCoords[] = {
				texfrag.r, texfrag.t,
				texfrag.l, texfrag.t,
				texfrag.l, texfrag.b,
				texfrag.r, texfrag.b,
			};
			glTexCoordPointer(2, GL_FLOAT, 0, texCoords);
		} else {
			GLfloat texCoords[] = {
				texfrag.r, texfrag.b,
				texfrag.l, texfrag.b,
				texfrag.l, texfrag.t,
				texfrag.r, texfrag.t,
			};
			glTexCoordPointer(2, GL_FLOAT, 0, texCoords);
		}
	} else {
		if (tile->flags & TILE_FLIP_Y) {
			GLfloat texCoords[] = {
				texfrag.l, texfrag.t,
				texfrag.r, texfrag.t,
				texfrag.r, texfrag.b,
				texfrag.l, texfrag.b,
			};
			glTexCoordPointer(2, GL_FLOAT, 0, texCoords);
		} else {
			GLfloat texCoords[] = {
				texfrag.l, texfrag.b,
				texfrag.r, texfrag.b,
				texfrag.r, texfrag.t,
				texfrag.l, texfrag.t,
			};
			glTexCoordPointer(2, GL_FLOAT, 0, texCoords);
		}
	}
	glDrawArrays(GL_QUADS, 0, 4);
}

void
draw_quad(Camera *cam, BB *bb_arg, float color[4])
{
	BB bb;

	glDisable(GL_TEXTURE_2D);

	bb = *bb_arg;
	bb.l -= round(cam->body.pos.x);
	bb.r -= round(cam->body.pos.x);
	bb.b -= round(cam->body.pos.y);
	bb.t -= round(cam->body.pos.y);
	
	glColor4fv(color);
	glBegin(GL_QUADS);
	  glVertex2f(bb.l, bb.b);
	  glVertex2f(bb.r, bb.b);
	  glVertex2f(bb.r, bb.t);
	  glVertex2f(bb.l, bb.t);
	glEnd();
	
	glEnable(GL_TEXTURE_2D);
}

static void
draw_node(QTreeNode *node)
{
	int i;
	BB *bb;

	bb = &node->bb;
	glBegin(GL_LINE_LOOP);
	  glVertex2i(bb->l, bb->t);
	  glVertex2i(bb->l, bb->b);
	  glVertex2i(bb->r, bb->b);
	  glVertex2i(bb->r, bb->t);
	glEnd();
	
	/* Draw child nodes recursively. */
	for (i = 0; i < 4; i++) {
		if (node->kids[i] != NULL)
			draw_node(node->kids[i]);
	}
}

void
draw_qtree(const QTree *tree)
{
	assert(tree != NULL && tree->root != NULL);

	glDisable(GL_TEXTURE_2D);
	glColor3f(0.8, 0.6, 0.4);
	glLineWidth(2.0);
	
	/* Draw all nodes recursively. */
	draw_node(tree->root);
	
	glEnable(GL_TEXTURE_2D);
}

/*
 * Draw a point.
 */
void
draw_point(vect_f p)
{
	glDisable(GL_TEXTURE_2D);
	glPointSize(5.0);
	glColor3f(1.0, 0.0, 1.0);
	glBegin(GL_POINTS);
	  glVertex2f(p.x, p.y);
	glEnd();
	glEnable(GL_TEXTURE_2D);
}

/*
 * Draw shape.
 */
void
draw_shape(const Shape *s)
{
	assert(s != NULL && s->objtype == OBJTYPE_SHAPE && s->body != NULL);

	Matrix m;
	float body_pos[4] = {round(s->body->pos.x), round(s->body->pos.y), 0.0, 1.0};
	m_set_translate(&m, body_pos);
	//m_rotZ(&m, s->body->a);
	glPushMatrix();
	glMultMatrixf(m.val);
	
	/* Draw intersecting shapes some special color. */
	if (s->flags & SHAPE_INTERSECT)
		glColor4f(1.0, 0.0, 0.0, 0.5);
	else
		glColor4fv(s->color);
	
	switch (s->shape_type) {
	case SHAPE_RECTANGLE: {		
		glBegin(GL_LINE_LOOP);
		  glVertex2f(s->shape.rect.l, s->shape.rect.t);
		  glVertex2f(s->shape.rect.l, s->shape.rect.b);
		  glVertex2f(s->shape.rect.r, s->shape.rect.b);
		  glVertex2f(s->shape.rect.r, s->shape.rect.t);
		glEnd();
		break;
	}
	case SHAPE_CIRCLE: {
		Circle c;
		int i, n;
		float f;
		
		glBegin(GL_LINE_LOOP);
		c = s->shape.circle;
		n = MAX2(3, log(c.radius) * 5.0);
		for (i = 0; i <= n; i++) {
			f = 2.0*PI*i/n;
			glVertex2f(c.offset.x + c.radius * cos(f),
			    c.offset.y + c.radius * sin(f));
		}
		glEnd();
		break;
	}
	default:
		log_err("Unknown shape type (%i).", s->shape_type);
		abort();
	}

	glPopMatrix();
}

void
draw_tile(const Camera *cam, Tile *tile)
{
	assert(cam != NULL && tile != NULL && tile->body != NULL);
	
	/* Calculate current frame index (for animating tiles). */
	tile_update_frameindex(tile);
	
	if (tile->hidden) return;

	/* If there are no attachments, draw the sprite and bail out. */
	draw_sprite(tile, cam);
}

void
draw_BB(const BB *bb)
{
	glDisable(GL_TEXTURE_2D);
	glLineWidth(1.0);
	glBegin(GL_LINE_LOOP);
	  glVertex2f(bb->l, bb->b);
	  glVertex2f(bb->r, bb->b);
	  glVertex2f(bb->r, bb->t);
	  glVertex2f(bb->l, bb->t);
	glEnd();
	glEnable(GL_TEXTURE_2D);
}

void
draw_axes()
{
	float size = 100.0;
	
	glDisable(GL_TEXTURE_2D);
	glLineWidth(1.0);
	
	glBegin(GL_LINES);
	  glColor3f(0.3, 0.0, 0.0);
	  /* Axis. */
	  glVertex2f(-size, 0.0);
	  glVertex2f( size, 0.0);
	  /* Mark at (-1, 0). */
	  glVertex2f(-size/2.0, -size/20.0);
	  glVertex2f(-size/2.0,  size/20.0);
	  /* Mark at (1, 0). */
	  glVertex2f(size/2.0, -size/20.0);
	  glVertex2f(size/2.0,  size/20.0);

	  glColor3f(0.0, 0.3, 0.0);
	  /* Axis. */
	  glVertex2f(0.0, -size);
	  glVertex2f(0.0,  size);
	  /* Mark at (0, -1). */
	  glVertex2f(-size/20.0, -size/2.0);
	  glVertex2f( size/20.0, -size/2.0);
	  /* Mark at (0, 1). */
	  glVertex2f(-size/20.0, size/2.0);
	  glVertex2f( size/20.0, size/2.0);

	glEnd();
	glEnable(GL_TEXTURE_2D);
}
