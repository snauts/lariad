#include <assert.h>
#include <lua.h>
#include <math.h>
#include "game2d.h"
#include "log.h"
#include "lua_util.h"
#include "mem.h"
#include "misc.h"
#include "world.h"
#include "utlist.h"

static Texture	*texture_hash;

void
tf_init(TexFrag *tf, float l, float b, float r, float t)
{
	tf->l = l;
	tf->t = t;
	tf->r = r;
	tf->b = b;
}

void
parallax_init(Parallax *px, World *world, SpriteList *sprite_list,
    vect_i size, vect_i offset, vect_f mult, float depth)
{
	int i;
	
	assert(px != NULL && sprite_list != NULL);
	assert((size.x == 0 && size.y == 0) || (size.x > 0.0 && size.y > 0.0));
	
	px->objtype = OBJTYPE_PARALLAX;
	body_init(&px->body, world, vect_f_zero, BODY_SPECIAL);
	
	px->sprite_list = sprite_list;
	px->frame_index = 0;
	px->color = 0xFFFFFFFF;
	px->anim_type = TILE_ANIM_NONE;
	px->anim_start = 0.0;
	px->anim_FPS = 0.0;
	px->size = size;
	px->offset = offset;
	px->mult = mult;
	memset(&px->spacing, 0, sizeof(px->spacing));
	px->depth = depth;
	px->flags = 0;
	
	/* Add parallax to world: find an unused parallax pointer and store
	   it there. */
	for (i = 0; i < WORLD_PX_PLANES_MAX; i++) {
		if (world->px_planes[i] == NULL)
			break;
	}
	assert(i != WORLD_PX_PLANES_MAX);	/* Must find a free spot. */
	world->px_planes[i] = px;			/* Store px pointer. */
}

Parallax *
parallax_new(World *world, SpriteList *sprite_list, vect_i size,
    vect_i offset, vect_f mult, float depth)
{
	extern mem_pool mp_parallax;
	Parallax *px;
	
	px = mp_alloc(&mp_parallax);
	parallax_init(px, world, sprite_list, size, offset, mult, depth);
	return px;
}

void
parallax_destroy(Parallax *px)
{
	assert(px != NULL);
	body_destroy(&px->body);
	memset(px, 0, sizeof(Parallax));
}

void
parallax_free(Parallax *px)
{
	extern mem_pool mp_parallax;
	parallax_destroy(px);
	mp_free(&mp_parallax, px);
}

/*
 * Destroy old parallax tiles and create new ones.
 */
void
parallax_update(Parallax *px, const Camera *cam)
{
	int i, j;
	vect_i offset;
	vect_i size, pos;
	BB viewport, cells;
	TexFrag texfrag;
	Tile *tile;

	assert(px != NULL);
	assert(px->sprite_list != NULL && px->sprite_list->num_frames > 0);

	/* Destroy old tiles. */
	while (px->body.tiles != NULL)
		tile_free(px->body.tiles);

	/* Parallax body always has the same position as camera body. */
	px->body.pos = vect_f_round(cam->body.pos);
	px->body.prevframe_pos = vect_f_round(cam->body.prevframe_pos);
	
	size = px->size;
	if (size.x == 0 && size.y == 0) {
		/* If parallax tile size is zero, we use sprite current frame
		   width and height. */
		texfrag = px->sprite_list->frames[px->frame_index]; /* Texture fragment box. */
		size.x = round((texfrag.r - texfrag.l) * px->sprite_list->tex->pow_w);
		size.y = round((texfrag.b - texfrag.t) * px->sprite_list->tex->pow_h);
	}

	viewport.l = floor(-cam->size.x/(2*cam->zoom));
	viewport.r = ceil(+cam->size.x/(2*cam->zoom));
	viewport.b = floor(-cam->size.y/(2*cam->zoom));
	viewport.t = ceil(+cam->size.y/(2*cam->zoom));

	offset = px->offset;
	offset.x -= round(px->body.pos.x * px->mult.x);
	offset.y -= round(px->body.pos.y * px->mult.y);
	cells.l = floor((double)(viewport.l-offset.x) / (size.x + px->spacing.x));
	cells.r = ceil((double)(viewport.r-offset.x) / (size.x + px->spacing.x));
	cells.b = floor((double)(viewport.b-offset.y) / (size.y + px->spacing.y));
	cells.t = ceil((double)(viewport.t-offset.y) / (size.y + px->spacing.y));

	if (!(px->flags & PX_REPEAT_X)) {
		cells.l = 0;
		cells.r = 1;
	}
	if (!(px->flags & PX_REPEAT_Y)) {
		cells.b = 0;
		cells.t = 1;
	}
	for (i = cells.l; i < cells.r; i += 1) {
		pos.x = offset.x + i * (size.x + px->spacing.x);
		for (j = cells.b; j < cells.t; j += 1) {
			pos.y = offset.y + j * (size.y + px->spacing.y);

			/* Culling. */
			if (pos.x > ceil(+cam->size.x/(2*cam->zoom)))
				continue;
			if (pos.x + size.x < floor(-cam->size.x/(2*cam->zoom)))
				continue;
			if (pos.y > ceil(+cam->size.y/(2*cam->zoom)))
				continue;
			if (pos.y + size.y < floor(-cam->size.y/(2*cam->zoom)))
				continue;

			/* Create parallax tile. */
			tile = tile_new(&px->body, pos, size, px->sprite_list,
			    px->depth);
			tile->frame_index = px->frame_index;
			if ((px->flags & PX_ALTERFLIP_X) && (i % 2))
				tile->flags |= TILE_FLIP_X;
			if ((px->flags & PX_ALTERFLIP_Y) && (j % 2))
				tile->flags |= TILE_FLIP_Y;
			
			/* Copy animation parameters and color into the new
			   tile. */
			tile->anim_type = px->anim_type;
			tile->anim_start = px->anim_start;
			tile->anim_FPS = px->anim_FPS;
			tile->color = px->color;
		}
	}
}

void
cam_init(Camera *cam, World *world, vect_i size, const BB *viewport)
{
	assert(cam != NULL && world != NULL);
	assert(size.x > 0 && size.y > 0);
	assert(viewport->r - viewport->l > 0 && viewport->b - viewport->t > 0);

	cam->objtype = OBJTYPE_CAMERA;

	/* Set up camera's body. */
	body_init(&cam->body, world, vect_f_zero, BODY_SPECIAL);
	
	cam->size = size;
	cam->zoom = 1.0;
	cam->viewport = *viewport;
	bb_init(&cam->box, 0, 0, 0, 0);
	cam->sort = 0;
}

Camera *
cam_new(World *world, vect_i size, BB *viewport)
{
	extern mem_pool mp_camera;
	Camera *cam;

	cam = mp_alloc(&mp_camera);
	cam_init(cam, world, size, viewport);
	return cam;
}

void
cam_free(Camera *cam)
{
	extern mem_pool mp_camera;
	cam_destroy(cam);
	mp_free(&mp_camera, cam);
}

void
cam_destroy(Camera *cam)
{
	assert(cam != NULL);
	body_destroy(&cam->body);
	memset(cam, 0, sizeof(Camera));
}

void
cam_set_pos(Camera *cam, vect_f pos)
{
	assert(cam != NULL);

	cam->body.pos = pos;
	if (!bb_valid(cam->box))
		return;
	
	if (cam->body.pos.x - cam->size.x/(2*cam->zoom) < cam->box.l)
		cam->body.pos.x = cam->box.l + cam->size.x/(2*cam->zoom);
	else if (cam->body.pos.x + cam->size.x/(2*cam->zoom) > cam->box.r)
		cam->body.pos.x = cam->box.r - cam->size.x/(2*cam->zoom);

	if (cam->body.pos.y - cam->size.y/(2*cam->zoom) < cam->box.b)
		cam->body.pos.y = cam->box.b + cam->size.y/(2*cam->zoom);
	else if (cam->body.pos.y + cam->size.y/(2*cam->zoom) > cam->box.t)
		cam->body.pos.y = cam->box.t - cam->size.y/(2*cam->zoom);
}

void
cam_view(const Camera *cam, Matrix *m)
{
	assert(cam != NULL && m != NULL);
	float rev_pos[4] = {-cam->body.pos.x, -cam->body.pos.y, 0.0, 1.0};
	m_set_translate(m, rev_pos);
}

void
cam_view_inv(const Camera *cam, Matrix *m)
{
	assert(cam != NULL && m != NULL);
	float pos[4] = {cam->body.pos.x, cam->body.pos.y, 0.0, 1.0};
	m_set_translate(m, pos);
}

static Texture *
texture_alloc()
{
	extern mem_pool mp_texture;
	return mp_alloc(&mp_texture);
}

/*
 * Release resources held inside texture struct. Namely, call glDeleteTextures()
 * for the texture ID.
 */
static void
texture_destroy(Texture *tex)
{
	assert(tex != NULL);
	
	log_msg("Deleting texture '%s' (id=%i).", tex->name, tex->id);
	glDeleteTextures(1, &tex->id);
	
	memset(tex, 0, sizeof(*tex));
	strcpy(tex->name, "Unused texture");
}

/*
 * Release any resources held inside texture struct, and then free the texture
 * struct itself.
 */
static void
texture_free(Texture *tex)
{
	extern mem_pool mp_texture;
	assert(tex != NULL);
        
        /* Free owned sprite-lists. */
        while (tex->sprites != NULL) {
                SpriteList *sprite_list = tex->sprites;
                HASH_DEL(tex->sprites, sprite_list);
                spritelist_free(sprite_list);
        }
        
	texture_destroy(tex);
	mp_free(&mp_texture, tex);
}

/*
 * Free all textures, clean out texture_hash.
 */
void
texture_free_all()
{
	Texture *tex;
	
	while (texture_hash) {
		tex = texture_hash;
		HASH_DEL(texture_hash, tex);
		texture_free(tex);
	}
}

/*
 * Free textures that have not been used in a while.
 */
void
texture_free_unused()
{
	Texture *tex, *tmp;
	
	HASH_ITER(hh, texture_hash, tex, tmp) {
		if (--tex->usage < 1) {
			HASH_DEL(texture_hash, tex);
			texture_free(tex);
		}
	}
}

/*
 * Look up texture struct by name in the global texture_hash. If it's not there,
 * create a new texture.
 *
 * name		This is usually the file name of the texture image. A filter
 *		attribute can be prepended to the filename like so:
 *		"f=1;path/to/image"
 *		If that's the case, linear filtering is used instead of
 *		GL_NEAREST.
 */

extern uint bound_texture;

Texture *
texture_lookup_or_create(const char *name)
{
	GLint filter;
	Texture *tex;
	
	/* See if a texture with this name already exists. */
	HASH_FIND_STR(texture_hash, name, tex);
	if (tex != NULL) {
		/* Reset usage counter and return texture. */
		tex->usage = TEXTURE_HISTORY;
		return tex;
	}
	
	/* A new texture. */
	tex = texture_alloc();
	assert(strlen(name) < TEXTURE_NAME_MAX);
        tex->sprites = NULL;
	strcpy(tex->name, name);
	
	/* Extract the actual filename and filter setting. */
	if (memcmp(name, "f=1;", 4) == 0) {
		name = &name[4];
		filter = GL_LINEAR;
	} else
		filter = GL_NEAREST;
	
	glGenTextures(1, &tex->id);
	glBindTexture(GL_TEXTURE_2D, tex->id);
	bound_texture = tex->id;
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);
	
	/* load_texture_from_file() initializes "w", "h", "pow_w", "pow_h", and
	   "name" texture struct members. */
	load_texture_from_file(tex, name);

	GLenum error;
	while ((error = GL_GetError()) != GL_NO_ERROR) {
		log_warn("OpenGL error: %s", getGLErrorString(error))
	}
	
	/* Mark texture as recently used. */
	tex->usage = TEXTURE_HISTORY;
	
	/* Add texture to global hash which is indexed by texture name. */
	HASH_ADD_STR(texture_hash, name, tex);
	return tex;
}

static SpriteList *
spritelist_alloc()
{
	extern mem_pool mp_sprite;
	return mp_alloc(&mp_sprite);
}

SpriteList *
spritelist_new(Texture *tex, TexFrag *frames, uint num_frames)
{
        /* See if a sprite list with the same exact frames already exists. */
        assert(tex && frames && num_frames > 0);
        SpriteList *s;
        uint framebuf_sz = num_frames * sizeof(TexFrag);
        HASH_FIND(hh, tex->sprites, frames, framebuf_sz, s);
        if (s != NULL)
                return s; /* Found it! */
        
        /* Allocate and initialize. */
        extern mem_pool mp_sprite;
        s = mp_alloc(&mp_sprite);
        s->objtype = OBJTYPE_SPRITELIST;
        s->tex = tex;
        
        /* Allocate space for sprites and copy them from argument buffer. */
        s->num_frames = num_frames;
        s->frames = mem_alloc(framebuf_sz, "Sprites");
        memcpy(s->frames, frames, framebuf_sz);
        
        /* Add sprite-list to hash and return it. */
        HASH_ADD_KEYPTR(hh, tex->sprites, s->frames, framebuf_sz, s);
        return s;
}

void
spritelist_free(SpriteList *s)
{
        assert((s->num_frames == 0 && s->frames == NULL) ||
               (s->num_frames > 0 && s->frames != NULL));
        
        /* Release frame memory. */
        mem_free(s->frames);
        
        /* Free sprite-list memory. */
        extern mem_pool mp_sprite;
        mp_free(&mp_sprite, s);
        memset(s, 0, sizeof(*s));
}

Tile *
tile_new(Body *body, vect_i pos, vect_i size, SpriteList *sprite_list,
    float depth)
{
	extern mem_pool mp_tile;
	Tile *t;
	
	t = mp_alloc(&mp_tile);
	tile_init(t, body, pos, size, sprite_list, depth);
	return t;
}

void
tile_init(Tile *tile, Body *body, vect_i pos, vect_i size,
    SpriteList *sprite_list, float depth)
{
	assert(tile != NULL);
	assert(body != NULL);

	tile->objtype = OBJTYPE_TILE;
	tile->body = body;
	
	tile->sprite_list = sprite_list;
	tile->frame_index = 0;
	
	tile->angle = 0.0;
	tile->color = 0xFFFFFFFF;
	
	tile->anim_type = TILE_ANIM_NONE;
	tile->anim_start = 0.0;
	tile->anim_FPS = 0.0;
	
	tile->pos = pos;
	tile->size = size;
	tile->depth = depth;
	tile->flags = 0;

	DL_APPEND(body->tiles, tile);		/* Add to body's tile list. */
	qtree_obj_init(&tile->go, tile);	/* Ready for quad tree. */
}

void
tile_destroy(Tile *tile)
{
	QTree *tree;
	assert(tile != NULL && tile->body != NULL);

	/* Remove from quad tree if it's in there. */
	if (tile->go.stored) {
		tree = &tile->body->world->tile_tree;
		qtree_remove(tree, &tile->go);
	}

	/* Remove from body's list if the tile was ever added to it. */
	if (tile->prev != NULL || tile->next != NULL) {
		assert(tile->body->tiles != NULL);
		DL_DELETE(tile->body->tiles, tile);
	}
	
	memset(tile, 0, sizeof(Tile));
}

void
tile_free(Tile *t)
{
	extern mem_pool mp_tile;
	tile_destroy(t);
	mp_free(&mp_tile, t);
}

/*
 * Given tile animation parameters and time since animation start, calculate
 * what is the current frame (from tile's sprite list) that must be displayed.
 * Update the frame_index member variable accordingly.
 */
void
tile_update_frameindex(Tile *tile)
{
	int *fi;
	double now, delta;
	World *world;
	
	assert(tile != NULL && tile->sprite_list != NULL);
	fi = &tile->frame_index;	/* A shorter name. */
	
	/* Check in what way or if at all tile should be animated. */
	switch (tile->anim_type) {
	case TILE_ANIM_NONE:
		return;
	case TILE_ANIM_LOOP:
		world = tile->body->world;
		now = world->step * world->step_sec; /* World time. */
		delta = now - tile->anim_start;
		
		if (tile->anim_FPS >= 0.0) {
			*fi = floor(delta * tile->anim_FPS);
		} else {
			/* Frame index calculation for when we're going
			   backwards. */
			*fi = tile->sprite_list->num_frames -
			    floor(delta * -tile->anim_FPS) - 1;
		}
		
		if (*fi < 0) {
			*fi = tile->sprite_list->num_frames -
			    ((-*fi) % tile->sprite_list->num_frames);
		}
		*fi %= tile->sprite_list->num_frames;
		return;
	case TILE_ANIM_CLAMP:
		world = tile->body->world;
		now = world->step * world->step_sec; /* World time. */
		delta = now - tile->anim_start;
		
		if (tile->anim_FPS >= 0.0) {
			*fi = floor(delta * tile->anim_FPS);
		} else {
			/* Frame index calculation for when we're going
			   backwards. */
			*fi = tile->sprite_list->num_frames -
			    floor(delta * -tile->anim_FPS) - 1;
		}
		
		if (*fi < 0) {
			*fi = 0;
			
			/* We're in clamp mode, animation is going backwards.
			   If we've reached the first frame., there's no need to
			   keep animating, just leave frame index at 0. */
			if (tile->anim_FPS <= 0.0)
				tile->anim_type = TILE_ANIM_NONE;
		} else if (*fi >= tile->sprite_list->num_frames) {
			*fi = tile->sprite_list->num_frames - 1;
		
			/* We're in clamp mode, animation is going forward. If
			   we've reached the last frame, there's no need to keep
			   animating, just leave frame index as is. */
			if (tile->anim_FPS >= 0.0)
				tile->anim_type = TILE_ANIM_NONE;
		}
		return;
	case TILE_ANIM_REVERSE:
		fatal_error("ANIM_REVERSE not implemented yet!");
	default:
		fatal_error("Invalid tile animation type: (%i).",
		    tile->anim_type);
	}
	/* NOTREACHED */
}

/*
 * Remove and re-add tile to tile quad tree. Call this function whenever the
 * size or position of a tile changes. Including when the position of the body
 * that the tile belongs to changes.
 */
void
tile_update_tree(Tile *tile)
{
	vect_i pos;
	Body *body;
	
	/* Shorthand. */
	body = tile->body;

	/* Note that we must use absolute values of tile size
	   components. This is because if negative, then instead
	   _sprite_ size is used for drawing (not tile size), and tile
	   size contains the negated size of a bounding box that can
	   accomodate any sprite from the tile's sprite list. This
	   negated size is exactly what we need here, and is stored in
	   this way so we wouldn't have to recalculate it each time
	   this routine is called. */
	pos.x = tile->pos.x + round(body->pos.x);
	pos.y = tile->pos.y + round(body->pos.y);
	bb_init(&tile->go.bb, pos.x, pos.y, pos.x + abs(tile->size.x),
		     pos.y + abs(tile->size.y));
	qtree_update(&body->world->tile_tree, &tile->go);
}
