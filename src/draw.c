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

uint bound_texture = (uint) -1;
static uint blend_func = 0;

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
		glEnd();
		
		/* Switch texture if it differs from currently selected one. */
		if (bound_texture != sprite_list->tex->id) {
			glBindTexture(GL_TEXTURE_2D, sprite_list->tex->id);
			glTexEnvf(GL_TEXTURE_ENV,
				  GL_TEXTURE_ENV_MODE,
				  GL_MODULATE);
			bound_texture = sprite_list->tex->id;
		}
		
		/* Switch blending if it differs from the current one. */
		if (blend_func != (tile->flags & TILE_MULTIPLY)) {
			if (tile->flags & TILE_MULTIPLY)
				glBlendFunc(GL_ZERO, GL_SRC_COLOR);
			else
				glBlendFunc(GL_SRC_ALPHA,
					    GL_ONE_MINUS_SRC_ALPHA);
			blend_func = (tile->flags & TILE_MULTIPLY);
		}
		glBegin(GL_QUADS);
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

	if (tile->flags & TILE_FLIP_X) {
		if (tile->flags & TILE_FLIP_Y) {
			glTexCoord2f(texfrag.r, texfrag.t);
			glVertex2f(BL.x, BL.y);
			glTexCoord2f(texfrag.l, texfrag.t);
			glVertex2f(BR.x, BR.y);
			glTexCoord2f(texfrag.l, texfrag.b);
			glVertex2f(TR.x, TR.y);
			glTexCoord2f(texfrag.r, texfrag.b);
			glVertex2f(TL.x, TL.y);
		} else {
			glTexCoord2f(texfrag.r, texfrag.b);
			glVertex2f(BL.x, BL.y);
			glTexCoord2f(texfrag.l, texfrag.b);
			glVertex2f(BR.x, BR.y);
			glTexCoord2f(texfrag.l, texfrag.t);
			glVertex2f(TR.x, TR.y);
			glTexCoord2f(texfrag.r, texfrag.t);
			glVertex2f(TL.x, TL.y);
		}
	} else {
		if (tile->flags & TILE_FLIP_Y) {
			glTexCoord2f(texfrag.l, texfrag.t);
			glVertex2f(BL.x, BL.y);
			glTexCoord2f(texfrag.r, texfrag.t);
			glVertex2f(BR.x, BR.y);
			glTexCoord2f(texfrag.r, texfrag.b);
			glVertex2f(TR.x, TR.y);
			glTexCoord2f(texfrag.l, texfrag.b);
			glVertex2f(TL.x, TL.y);
		} else {
			glTexCoord2f(texfrag.l, texfrag.b);
			glVertex2f(BL.x, BL.y);
			glTexCoord2f(texfrag.r, texfrag.b);
			glVertex2f(BR.x, BR.y);
			glTexCoord2f(texfrag.r, texfrag.t);
			glVertex2f(TR.x, TR.y);
			glTexCoord2f(texfrag.l, texfrag.t);
			glVertex2f(TL.x, TL.y);
		}
	}
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
		glColor4ubv((uchar *)&s->color);
	
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

	/* Set tile color. */
	glColor4ubv((uchar *)&tile->color);

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
