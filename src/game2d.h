#ifndef GAME2D_H
#define GAME2D_H

#include <SDL_opengl.h>
#include <lua.h>
#include "audio.h"
#include "qtree.h"
#include "geometry.h"
#include "physics.h"
#include "matrix.h"

struct World_t;
struct SpriteList_t;

/*
 * Structures and routines related to concepts of classic 2D gaming -- sprites,
 * tiles, etc.
 */

#define TEXTURE_NAME_MAX	100	/* Max length of texture filenames. */
#define TEXTURE_HISTORY		3	/* Determines how long unused textures
					   stay in memory. */

/*
 * Images are loaded as OpenGL textures. As such, both their width and height
 * must be numbers that are powers of two. If an image does not have power of
 * two dimensions, its buffer is extended to the smallest possible enclosing
 * power of two size.
 */
typedef struct {
	GLuint	id;		/* OpenGL texture ID. */
	char	name[TEXTURE_NAME_MAX]; /* Texture name = hash key. */
	int	w, h;		/* Image width and height in pixels. */
	int	pow_w, pow_h;	/* Power of two extended widht & height. */
	int	usage;		/* Determines how long ago texture was last
				   used. */
        struct SpriteList_t *sprites; /* Hash of sprite lists. */
	UT_hash_handle hh;	/* Makes this struct hashable. */
} Texture;

/*
 * Texture fragment.
 */
typedef struct {
	float l, b, r, t;
} TexFrag;

/*
 * A sprite list is a sequence of images. "Image" meaning piece of an OpenGL
 * texture. A sequence of images can be used for creating animation, but
 * timing and anything else related to selecting the current image is not part
 * of a sprite structure.
 *
 * Each "bounding box" in the frames list specifies a rectangular texture
 * fragment.
 */
typedef struct SpriteList_t {
	int		objtype;
	Texture		*tex;
	int		num_frames;	/* Number of frames. */
	TexFrag		*frames;	/* List of texture fragments. */
        UT_hash_handle  hh;             /* Makes this struct hashable. */
} SpriteList;

/* Tile flags. */
#define TILE_FLIP_X 	(1<<0)	/* Horizontal flip. */
#define TILE_FLIP_Y 	(1<<1)	/* Vertical flip. */
#define TILE_MULTIPLY 	(1<<2)	/* Multiply src onto dst */

enum TileAnimType {
	TILE_ANIM_NONE = 100,
	TILE_ANIM_LOOP,
	TILE_ANIM_CLAMP,
	TILE_ANIM_REVERSE
};

/*
 * A tile is like a canvas: drawing area specified by position and size.
 * A list of sprites (SpriteList) is always bound to a tile. One frame from this
 * sprite list is drawn at any one time (see frame_index member variable).
 * Tile's position is relative to its owner Body object, and it specifies the
 * position of its lower left corner.
 */
typedef struct Tile_t {
	int		objtype;		/* = OBJTYPE_TILE */
	struct Body_t	*body;			/* Body object = owner. */

	SpriteList	*sprite_list;		/* Graphic. */
	int		frame_index;		/* Active frame number. */

	float		angle;			/* rotation angle */
	float		color[4];    	/* Tile color. */
	
	/* Simple animation over all sprite list frames is described by the
	   following variables. */
	enum TileAnimType anim_type;		/* Animation type. */
	double		anim_start;		/* Animation start time. */
	double		anim_FPS;		/* Animation speed: frames per
						   second. */

	vect_i		pos;			/* Position relative to Body. */
	vect_i		size;			/* Tile size. */
	float		depth;			/* Determines drawing order. */
	uint		flags;
	int		hidden;

	QTreeObject	go;			/* Tile can be added to tree. */
	struct Tile_t *prev, *next;		/* For use in lists. */
} Tile;

/*
 * Camera (i.e., viewing & projection transform).
 */
typedef struct {
	int	objtype;	/* = OBJTYPE_CAMERA */
	Body	body;
	
	vect_i	size;		/* Width and height of physical area that
				   camera sees. */
	float	zoom;		/* Scale visible area size. */
	BB	viewport;	/* Viewport bounding box within window. */

	BB	box;		/* If the trackable object is within this box,
	                           don't show anything that's outside. */
	int	sort;		/* Determines camera sort order. Those with
				   smaller "sort" values will be rendered first.
				   */
} Camera;

/* Parallax flags. */
#define PX_REPEAT_X	(1<<0)	/* Repeat horizontally. */
#define PX_REPEAT_Y	(1<<1)	/* Repeat vertically. */
#define PX_ALTERFLIP_X	(1<<2)	/* Alternating horizontal flip. */
#define PX_ALTERFLIP_Y	(1<<3)	/* Alternating vertical flip. */

/*
 * Parallax background.
 */
typedef struct Parallax_t {
	int		objtype;	/* = OBJTYPE_PARALLAX */

	SpriteList	*sprite_list;
	int		frame_index;	/* Active frame number. */

	float	color[4];		/* Tile color. */
	
	/* Simple animation over all sprite list frames is described by the
	   following variables. */
	enum TileAnimType anim_type;	/* Animation type. */
	double		anim_start;	/* Animation start time. */
	double		anim_FPS;	/* Animation speed: frames per second.*/

	Body		body;		/* Tile list, really. */
	
	vect_i		offset;
	vect_i		size;
	vect_f		mult;
	vect_i		spacing;
	float		depth;

	uint		flags;
} Parallax;

void	tf_init(TexFrag *tf, float l, float b, float r, float t);

Parallax *parallax_new(struct World_t *world, SpriteList *sprite_list,
	      vect_i size, vect_i offset, vect_f mult, float depth);
void	parallax_init(Parallax *px, struct World_t *world,
	    SpriteList *sprite_list, vect_i size, vect_i offset, vect_f mult,
	    float depth);
void	parallax_destroy(Parallax *px);
void	parallax_free(Parallax *px);
void	parallax_update(Parallax *px, const Camera *cam);

Camera	*cam_new(struct World_t *world, vect_i size, BB *viewport);
void	cam_init(Camera *cam, struct World_t *world, vect_i size,
	    const BB *viewport);
void	cam_destroy(Camera *cam);
void	cam_free(Camera *cam);
void	cam_set_pos(Camera *cam, vect_f pos);
void	cam_view(const Camera *cam, Matrix *m);
void	cam_view_inv(const Camera *cam, Matrix *m);

Texture	*texture_lookup_or_create(const char *name);
void	 texture_free_all();
void	 texture_free_unused();

SpriteList      *spritelist_new(Texture *tex, TexFrag *frames, uint num_frames);
void		 spritelist_free(SpriteList *s);

void	 tile_init(Tile *t, Body *body, vect_i pos, vect_i size,
	     SpriteList *sprite_list, float depth);
Tile	*tile_new(Body *body, vect_i pos, vect_i size, SpriteList *sprite_list,
	     float depth);
void	 tile_destroy(Tile *t);
void	 tile_free(Tile *t);
void	 tile_update_frameindex(Tile *tile);
void	 tile_update_tree(Tile *tile);

#endif /* GAME2D_H */
