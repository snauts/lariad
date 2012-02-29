#include <assert.h>
#include <lua.h>
#include <lauxlib.h>
#include <math.h>
#include "audio.h"
#include "config.h"
#include "console.h"
#include "game2d.h"
#include "log.h"
#include "lua_util.h"
#include "misc.h"
#include "world.h"
#include "utlist.h"

/* Function that does nothing. */
static int
__Dummy(lua_State *L)
{
	UNUSED(L);
	return 0;
}

/*
 * What(obj) -> string
 *
 * Return a string describing what an object is ("Shape", "World", "Tile", etc).
 */
static int
What(lua_State *L)
{
	int objtype;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	/* All pointers that Lua scripts receive have an "objtype" integer as
	   their first structure member. We can simply cast any pointer to
	   (int *) and take a look at what's there. */
   	objtype = *(int *)lua_touserdata(L, 1);
	lua_pushstring(L, L_objtype_name(objtype));
	return 1;
}

/*
 * __BindKey(key, funcID)
 *
 * Bind a key (SDLK_LEFT, SDLK_z, etc) to a Lua function. The Lua functions are
 * stored in eapi.__idToObjectMap table (see eapi.lua) which is indexed by a
 * function (or any object) ID. Function IDs are generated incrementally (see
 * eapi.lua as well).
 * This is a "private" function, and scripts are supposed to use eapi.BindKey()
 * from eapi.lua.
 *
 * Use funcID == 0 to unbind a key.
 */
static int
__BindKey(lua_State *L)
{
	extern int *key_bind;
	int func_id, key;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TNUMBER);
	luaL_checktype(L, 2, LUA_TNUMBER);

	key = lua_tointeger(L, 1);
	func_id = lua_tointeger(L, 2);
	L_assert(L, key > SDLK_FIRST && key < SDLK_LAST + EXTRA_KEYBIND,
	    "Invalid key (%i).", key);
	L_assert(L, func_id >= 0, "Function ID must not be negative "
	    "(func_id: %i).", func_id);

	key_bind[key] = func_id;
	return 0;
}

/*
 * GetKeyBindings() -> {key1 = funcID_1, key2 = funcID_2, .., keyN = funcID_N}
 *
 * Return a table that contains all key bindings. This is useful for when you
 * wish to temporarily change keybindings, and then later restore the original
 * ones.
 */
static int
GetKeyBindings(lua_State *L)
{
	extern int *key_bind;
	int key;
	
	L_numarg_check(L, 0);
	
	lua_newtable(L);	/* ... {} */
	for (key = 0; key < SDLK_LAST + EXTRA_KEYBIND; key++) {
		if (key_bind[key] == 0)
			continue;
		lua_pushinteger(L, key);
		lua_pushinteger(L, key_bind[key]);
		lua_rawset(L, -3);
	}
	return 1;
}

/*
 * SetKeyBindings(bindingTable)
 *
 * bindingTable		Table of key bindings. Provide your own or use the table
 *			returned from GetKeyBindings(). An empty table will
 *			remove all key bindings.
 *
 * Clear and then set key bindings according to bindingTable. Use this function
 * to restore key bindings previously retrieved with GetKeyBindings().
 */
static int
SetKeyBindings(lua_State *L)
{
	extern int *key_bind;
	int key, func_id;
	
	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TTABLE);
	
	/* Unbind keys. */
	memset(key_bind, 0, sizeof(uint) * (SDLK_LAST + EXTRA_KEYBIND));
	
	lua_pushnil(L);  /* first key */
	while (lua_next(L, 1) != 0) {
		/* Get current key and corresponding function ID. */
		L_assert(L, lua_isnumber(L, -2) && lua_isnumber(L, -1),
		   "bindingTable must contain only integer keys and values.");
		key = lua_tointeger(L, -2);
		func_id = lua_tointeger(L, -1);
		L_assert(L, func_id >= 0, "Function ID must not be negative "
		    "(func_id: %i).", func_id);
		    
		/* Bind func_id to key. */
		key_bind[key] = func_id;
		lua_pop(L, 1);
	}
	
	return 0;
}

/*
 * __Collide(world, groupNameA, groupNameB, funcID, priority)
 *
 * world	World as returned by NewWorld().
 * groupNameA	groupNameA and groupNameB name the two shape collision groups
 *		that, after invoking this function with their names, are
 *		going to be considered for collisions.
 * groupNameB	see groupNameA.
 * funcID	Function ID (index into idToObjectMap -- see eapi.lua) that maps
 *		to a collision handler function that is going to be called
 *		whenever two shapes -- one belonging to group groupNameA and the
 *		other to groupNameB -- intersect.
 *		You can supply 0 here to remove a previously set collision
 *		handler.
 *		There can be only one collision handler per each pair of groups,
 *		so if a handler had already been registered for a particular
 *		pair, it is going to be overwritten with the new one.
 * priority	Priority determines the order in which collision handlers are
 * 		called for a particular pair of shapes.
 *		So let's say we have registered handlers for these two pairs:
 *			"Player" vs "Ground"
 *			"Player" vs "Exit".
 *		Now a shape belonging to group "Player" can be simultaneously
 *		colliding with both a "Ground" shape and an "Exit" shape. If
 *		priorities are the same for both handlers, then the order in
 *		which they will be executed is undetermined. We can, however,
 *		set the priority of "Player" vs "Ground" handler to be higher,
 *		so that it would always be executed first.
 */
static int
__Collide(lua_State *L)
{
	extern mem_pool mp_group;
	const char *nameA, *nameB;
	World *world;
	Group *groupA, *groupB;
	Handler *handler;
	int func_id, priority;
	
	L_numarg_check(L, 5);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TSTRING);
	luaL_checktype(L, 3, LUA_TSTRING);
	luaL_checktype(L, 4, LUA_TNUMBER);
	luaL_checktype(L, 5, LUA_TNUMBER);
	
	world = lua_touserdata(L, 1);
	L_assert_objtype(L, world, OBJTYPE_WORLD);
	L_assert(L, world->killme == 0, "Dying world");
	
	/* Extract both group names and function ID. */
	nameA = lua_tostring(L, 2);
	nameB = lua_tostring(L, 3);
	func_id = lua_tonumber(L, 4);
	priority = lua_tonumber(L, 5);
	
	/* Find group structures. */
	HASH_FIND_STR(world->groups, nameA, groupA);
	HASH_FIND_STR(world->groups, nameB, groupB);
	
	/* Create group A if it doesn't exist. */
	if (groupA == NULL) {
		groupA = mp_alloc(&mp_group);
		L_assert(L, strlen(nameA) < WORLD_GROUPNAME_LENGTH,
		    "Group name '%s' is too long", nameA);
		strcpy(groupA->name, nameA);
		groupA->id = world->next_group_id++;
		L_assert(L, groupA->id < WORLD_HANDLERS_MAX, "Too many shape "
		    "groups (%i).", groupA->id);
		HASH_ADD_STR(world->groups, name, groupA);
	}
	
	/* Create group B if it doesn't exist. */
	if (groupB == NULL) {
		groupB = mp_alloc(&mp_group);
		L_assert(L, strlen(nameB) < WORLD_GROUPNAME_LENGTH,
		    "Group name '%s' is too long", nameB);
		strcpy(groupB->name, nameB);
		groupB->id = world->next_group_id++;
		L_assert(L, groupB->id < WORLD_HANDLERS_MAX, "Too many shape "
		    "groups (%i).", groupB->id);
		HASH_ADD_STR(world->groups, name, groupB);
	}
	
	/* Get referenced handler; set handler functino ID and priority. */
	handler = &world->collision_map[groupA->id][groupB->id];
	handler->func_id = func_id;
	handler->priority = priority;
	
	return 0;
}

/*
 * Parse texture specification argument. It can either be a string:
 * 	"path/to/image"
 * or a table containing texture file name string and (optional) filter
 * attribute:
 *	{"path/to/image", filter=F}
 * where F=0 means GL_NEAREST filter, and F=1 means GL_LINEAR.
 *
 * As an example, these are all valid texture specifications:
 * 	{"image/player.png"}
 *	{"image/clouds.jpg", filter=1}
 *	"menu.png"
 *
 * In future there may be other attributes, but currently just the filter.
 *
 * name		Final texture name is written to this buffer. It must be at
 *		least TEXTURE_NAME_MAX bytes long.
 * filter	The type of filter specified (0 = GL_NEAREST and 1 = GL_LINEAR)
 *		is written to this address. If NULL, it is ignored.
 */
static void
texture_spec_parse(lua_State *L, int index, char *name)
{
	const char *raw_filename;
	
	assert(name != NULL);
	
	switch (lua_type(L, index)) {
	case LUA_TSTRING:
		raw_filename = lua_tostring(L, index);
		snprintf(name, TEXTURE_NAME_MAX, "%s", raw_filename);
		break;
	case LUA_TTABLE:
		lua_pushnumber(L, 1);
		lua_gettable(L, index);
		raw_filename = lua_tostring(L, -1);
		
		lua_getfield(L, index, "filter");
		if (lua_toboolean(L, -1)) {
			snprintf(name, TEXTURE_NAME_MAX, "f=1;%s",
			    raw_filename);
		} else
			snprintf(name, TEXTURE_NAME_MAX, "%s", raw_filename);
		break;
	default:
		luaL_error(L, "Invalid argument type (%s). Texture "
		    "specification should be either a filename string or "
		    "filename string together with filter setting in a table.",
		    lua_typename(L, lua_type(L, index)));
	}
	/* NOTREACHED */
}

/*
 * NewSpriteList(texture, subimage, ..) -> spriteList
 *
 * texture	Texture file name (e.g., "image/hello.png"). To do linear
 *		filtering on this texture, pass in a table in the following
 *		format instead: {filename, filter=1}.
 * subimage	A rectangular subimage specification. For reasons of clarity and
 * 		efficiency, it should never be that one texture contains only
 *		one image (unless it's huge). A sprite list contains multiple
 *		subimages (which can be used for animation).
 *		Each subimage specification can have one of two forms: vector
 * 		and bounding box.
 *		Vector form looks like this:
 *			{{s, t}, {w, h}}
 *		where {s, t} is the position in pixel coordinates and {w, h} is
 *		width and height in pixels.
 *		In bounding box form:
 *			{l=?, b=?, r=?, t=?}
 *		Left, bottom, right, top are the pixel coordinates of all four
 *		extremes (same idea as in bb (bounding box) type).
 *
 * Create a sprite list; pointer to the C structure is returned for later
 * reference.
 */
static int
NewSpriteList(lua_State *L)
{
	int n = lua_gettop(L);
	L_assert(L, n > 1, "Incorrect number of arguments.");
	
	/* Figure out what the name of the texture is, and try looking it up in
	   the global texture_hash. If not found, create a new texture. */
        char texname[TEXTURE_NAME_MAX];
	texture_spec_parse(L, 1, texname);
	Texture *tex = texture_lookup_or_create(texname);
        
	/*
	 * For each subimage spec figure out what form it is in. Then add the
	 * four texture coordinates to sprite's texture coordinate list.
	 */
        uint num_frames = 0;
        TexFrag tmp_frames[100];
	for (int i = 2; i <= n; i++) {
		luaL_checktype(L, i, LUA_TTABLE);
		lua_getfield(L, i, "l");
                
                float left, right, bottom, top;
		if (lua_isnil(L, -1)) {
			L_assert(L, lua_objlen(L, i) == 2,
			    "Expected {{s, t}, {w, h}}.");
			L_getlistitem(L, i, 1);	/* ... nil {s, t} */
			L_getlistitem(L, i, 2);	/* ... nil {s, t}, {w, h} */
			vect_f ST = L_getstk_vect_f(L, -2);
			vect_f WH = L_getstk_vect_f(L, -1);
			lua_pop(L, 3);		/* ... */
			left	= ST.x / tex->pow_w;
			bottom	= (ST.y + WH.y) / tex->pow_h;
			right	= (ST.x + WH.x) / tex->pow_w;
			top	= ST.y / tex->pow_h;
		} else {
                        TexFrag tf;
			L_getstk_TexFrag(L, i, &tf);
			left = (tf.l) / tex->pow_w;
			bottom = (tf.b) / tex->pow_h;
			right = (tf.r) / tex->pow_w;
			top = (tf.t) / tex->pow_h;
			lua_pop(L, 1);		/* ... */
		}
		assert(right > left && bottom > top); /* Is the sprite valid? */

		/* Add a TexFrag to the frame list. */
                assert(num_frames < sizeof(tmp_frames)/sizeof(TexFrag));
                tmp_frames[num_frames++] = (TexFrag){
                        .l = left,
                        .r = right,
                        .b = bottom,
                        .t = top
                };
	}

	/* Create sprite-list and return its pointer. */
        lua_pushlightuserdata(L, spritelist_new(tex, tmp_frames, num_frames));  
        return 1;
}

/*
 * NewParallax(world, spriteList, size={0,0}, offset={0,0}, multiplier, depth)
 * 	-> parallax
 *
 * world		World as returned by NewWorld().
 * spriteList		Sprite list as returned by NewSpriteList()
 * size			Width and height vector of the drawn image(s). If nil,
 *			the width and height of current sprite is used.
 * offset		Position of the parallax image, or an offset vector if
 *			they're repeated.
 * multiplier		Camera position {cx, cy} is multiplied by
 * 			multiplier {cx*mx, cy*my} to get the resulting offset.
 * 			If multiplier is between one and zero, the parallax
 *			effect is created: background appears to move slower
 * 			than foreground.
 * depth		Depth value determines drawing order. Into the screen is
 *			negative.
 */
static int
NewParallax(lua_State *L)
{
	vect_f mult;
	vect_i size = {0,0};
	vect_i offset = {0, 0};
	float depth;
	Parallax *px;
	SpriteList *sprite_list;
	World *world;
	
	L_numarg_check(L, 6);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 5, LUA_TTABLE);
	luaL_checktype(L, 6, LUA_TNUMBER);

	world = lua_touserdata(L, 1);
	L_assert_objtype(L, world, OBJTYPE_WORLD);
	L_assert(L, world->killme == 0, "Dying world");
	
	sprite_list = lua_touserdata(L, 2);
	L_assert_objtype(L, sprite_list, OBJTYPE_SPRITELIST);
	if (!lua_isnoneornil(L, 3))
		size = L_getstk_vect_i(L, 3);
	if (!lua_isnoneornil(L, 4))
		offset = L_getstk_vect_i(L, 4);
	mult = L_getstk_vect_f(L, 5);
	depth = lua_tonumber(L, 6);

	L_assert(L, (size.x == 0 && size.y == 0) ||
	    (size.x > 0.0 && size.y > 0.0),
	    "Parallax tile size must be positive.");

	/* Create Parallax and add it to world. */
	px = parallax_new(world, sprite_list, size, offset, mult, depth);
	px->flags |= (PX_REPEAT_X | PX_REPEAT_Y);
	
	lua_pushlightuserdata(L, px);
	return 1;
}

/*
 * __Destroy(...)
 *
 * ...		Accepted objects: Body, Shape, Tile, World.
 *
 * Free any resources owned by objects. Passing an object into API routines
 * after it has been destroyed will result in assertion failures saying it is of
 * incorrect type. It is also possible (though unlikely) that its memory has
 * been reused by some other object in which case the other object will be
 * affected.
 */
static int
__Destroy(lua_State *L)
{
	int *objtype, n, i;

	n = lua_gettop(L);
	for (i = 1; i <= n; i++) {
		luaL_checktype(L, i, LUA_TLIGHTUSERDATA);

		objtype = lua_touserdata(L, i);
		L_assert(L, objtype != NULL, "NULL object pointer.");

		switch (*objtype) {
		case OBJTYPE_BODY: {
			body_free(lua_touserdata(L, i));
			break;
		}
		case OBJTYPE_SHAPE: {
			shape_free(lua_touserdata(L, i));
			break;
		}
		case OBJTYPE_TILE: {
			tile_free(lua_touserdata(L, i));
			break;
		}
		case OBJTYPE_WORLD: {
			World *world = lua_touserdata(L, i);
			L_assert(L, world->killme == 0, "Dying world");
			
			/* Schedule for complete destruction and fade out all
			   sounds bound to this world. */
			world->killme = 1;
			audio_fadeout_group((uintptr_t)world, 1000);

			/* Destroy resources owned by world. */
			world_clear(world);
			break;
		}
		default:
			L_objtype_error(L, *objtype);
		}
	}
	return 0;
}

/*
 * NewCamera(world, pos, size, viewport, sort) -> camera
 *
 * world	World as returned by NewWorld().
 * pos		Position vector. nil means {0, 0}.
 * size		Size vector: size of the area that camera is able to see.
 * 		Passing zero as one of the two dimensions makes the engine
 *		calculate the other one based on viewport size (same aspect
 *		ratio for both). If nil, size is the same as viewport size.
 * viewport	Area of the window that camera draws to. Specified as bounding
 *		box: {l=?,r=?,b=?,t=?}, assuming coordinates are in pixels, with
 *		top left corner being (0,0). If nil, draw to the whole window.
 * sort		Determines camera sort order. Those with smaller "sort" values
 *		will be rendered first (Note: the sort feature has not been
 *		implemented yet).
 */
static int
NewCamera(lua_State *L)
{
	extern Camera *cameras[CAMERAS_MAX];
	int i, screen_w, screen_h;
	vect_f pos = {0.0, 0.0};
	vect_i size = {0,0};
	BB viewport;
	World *world;

	L_numarg_check(L, 4);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	screen_w = GET_CFG("screenWidth", cfg_get_int, 800);
	screen_h = GET_CFG("screenHeight", cfg_get_int, 480);

	world = lua_touserdata(L, 1);
	L_assert_objtype(L, world, OBJTYPE_WORLD);
	L_assert(L, world->killme == 0, "Dying world");
	
	/* Get position if it is given. */
	if (!lua_isnil(L, 2))
		pos = L_getstk_vect_f(L, 2);
		
	/* Init viewport box. */
	if (lua_isnil(L, 4))
		bb_init(&viewport, 0, screen_h, screen_w, 0);
	else
		L_getstk_BB(L, 4, &viewport);
	L_assert(L, viewport.r > viewport.l && viewport.b > viewport.t,
	    "Invalid viewport.");
	    
	if (!lua_isnil(L, 3)) {
		size = L_getstk_vect_i(L, 3);
	} else {
		size.x = viewport.r - viewport.l;
		size.y = viewport.b - viewport.t;
	}
	L_assert(L, size.x >= 0 && size.y >= 0, "Invalid camera size: "
	    "{%i, %i}.", size.x, size.y);
	L_assert(L, size.x > 0 || size.y > 0, "Invalid camera size: "
	    "{%i, %i}.", size.x, size.y);

	/* If one of the size components is zero, compute the other one using
	   viewport aspect ratio. */
	if (size.x == 0)
		size.x = round(size.y*(viewport.r-viewport.l)/(viewport.b-viewport.t));
	if (size.y == 0)
		size.y = round(size.x*(viewport.b-viewport.t)/(viewport.r-viewport.l));
	
	/* Find an unused camera pointer. */
	for (i = 0; i < CAMERAS_MAX; i++) {
		if (cameras[i] == NULL)
			break;
	}
	L_assert(L, i != CAMERAS_MAX, "Too many cameras.");
	
	cameras[i] = cam_new(world, size, &viewport);
	body_set_pos(&cameras[i]->body, pos);
	
	lua_pushlightuserdata(L, cameras[i]);
	return 1;
}

/*
 * NewPath(interpType, open, outside, motion) -> path object
 */
static int
NewPath(lua_State *L)
{
	UNUSED(L);
	return 1;
}

/*
 * BindToPath(object, path, startPos, speed)
 */
static int
BindToPath(lua_State *L)
{
	UNUSED(L);
	return 0;
}

/*
 * ShowCursor()
 *
 * Show default mouse cursor.
 */
static int
ShowCursorFunc(lua_State *L)
{
	L_numarg_check(L, 0);
	SDL_ShowCursor(SDL_ENABLE);
	return 0;
}

/*
 * ShowCursor()
 *
 * Show default mouse cursor.
 */
static int
HideCursor(lua_State *L)
{
	L_numarg_check(L, 0);
	SDL_ShowCursor(SDL_DISABLE);
	return 0;
}

/*
 * SwitchFramebuffer()
 *
 * Start drawing in other framebuffer.
 */
static int
SwitchFramebuffer(lua_State *L)
{
	extern void switch_framebuffer(void);
	L_numarg_check(L, 0);
	switch_framebuffer();
	return 0;
}

/*
 * FadeFramebuffer()
 *
 * Fade to new framebuffer
 */
static int
FadeFramebuffer(lua_State *L)
{
	extern void fade_to_other_framebuffer(int);
	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TNUMBER);
	fade_to_other_framebuffer(lua_tonumber(L, 1));
	return 0;
}

/*
 * NewWorld(name, stepDuration, quadTreeDepth) -> world
 *
 * name			String parameter: choose a unique name for this world.
 * stepDuration		Duration of each world step in milliseconds.
 * quadTreeDepth	Number of levels in the quad tree that partitions space.
 *			Shouldn't be more than 20. A good idea is to start with
 *			10, then increase if necessary.
 *
 * Create a new world and return its pointer. World is the topmost
 * data structure (see world.h).
 */
static int
NewWorld(lua_State *L)
{
	extern World *worlds[WORLDS_MAX];
	int i, tree_depth, step_duration;
	const char *name;

	L_numarg_check(L, 3);
	luaL_checktype(L, 1, LUA_TSTRING);
	luaL_checktype(L, 2, LUA_TNUMBER);
	luaL_checktype(L, 3, LUA_TNUMBER);
	
	/* Get world name and make sure it is unique. */
	name = lua_tostring(L, 1);
	L_assert(L, strlen(name) < WORLD_NAME_LENGTH, "World name maximum "
	    "length (%i) exceeded.", WORLD_NAME_LENGTH-1);
#ifndef NDEBUG
	for (i = 0; i < WORLDS_MAX; i++) {
		if (worlds[i] == NULL || worlds[i]->killme)
			continue;	/* Ignore dead or dying worlds. */
		if (strcmp(worlds[i]->name, name) == 0) {
			luaL_error(L, "World with name '%s' already exists.",
			    name);
		}
	}
#endif /* Debug mode. */
	step_duration = lua_tonumber(L, 2);
	L_assert(L, step_duration > 0, "World step duration must be positive.");
	
	tree_depth = lua_tonumber(L, 3);
	L_assert(L, tree_depth > 0 && tree_depth < 21, "quadTreeDepth "
	    "should fall within range [1, 20].");
	
	/* Find a free world slot. */
	for (i = 0; i < WORLDS_MAX; i++) {
		if (worlds[i] == NULL)
			break;
	}
	L_assert(L, i != WORLDS_MAX, "Too many worlds.");

	worlds[i] = world_new(name, step_duration, tree_depth);
	lua_pushlightuserdata(L, worlds[i]);
	return 1;
}

/*
 * NextCamera(cam) -> nextCamera
 *
 * cam		Camera as returned by NewCamera(), or nil to return first camera
 *		from the list.
 *
 * Iterate over cameras.
 */
static int
NextCamera(lua_State *L)
{
	extern Camera *cameras[CAMERAS_MAX];
	int i;
	Camera *cam;

	L_numarg_check(L, 1);
	if (lua_isnil(L, 1)) {
		/* Find a camera. */
		for (i = 0; i < CAMERAS_MAX; i++) {
			if (cameras[i] != NULL)
				break;
		}
		if (i == CAMERAS_MAX) {
			lua_pushnil(L);	/* No cameras! */
			return 1;
		}
		lua_pushlightuserdata(L, cameras[i]);
		return 1;
	}

	cam = lua_touserdata(L, 1);
	L_assert_objtype(L, cam, OBJTYPE_CAMERA);

	/* Find argument camera's index into camera array. */
	for (i = 0; i < CAMERAS_MAX; i++) {
		if (cameras[i] == cam)
			break;
	}
	assert(i != CAMERAS_MAX);

	/* Find the next non-NULL camera pointer. */
	for (i = (i+1)%CAMERAS_MAX;; i = (i+1)%CAMERAS_MAX) {
		if (cameras[i] != NULL) {
			lua_pushlightuserdata(L, cameras[i]);
			return 1;
		}
	}
}

/*
 * Pause(world)
 *
 * Pause world.
 */
static int
Pause(lua_State *L)
{
	World *world;
	
	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	
	world = lua_touserdata(L, 1);
	L_assert_objtype(L, world, OBJTYPE_WORLD);
	L_assert(L, world->killme == 0, "Dying world");
	
	/* Pause world audio. */
	audio_pause_group((uintptr_t)world);
	
	world->paused = 1;
	return 0;
}

/*
 * Resume(world)
 *
 * Resume world.
 */
static int
Resume(lua_State *L)
{
	World *world;
	
	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	
	world = lua_touserdata(L, 1);
	L_assert_objtype(L, world, OBJTYPE_WORLD);
	L_assert(L, world->killme == 0, "Dying world");
	
	/* Resume world audio. */
	audio_resume_group((uintptr_t)world);
	
	world->paused = 0;
	return 0;
}

/*
 * SetRepeatPattern(parallax, direction, spacing, flip)
 *
 * parallax		Parallax object as returned by NewParallax().
 * direction		Pair of booleans {h, v}. H -- if true, repeat
 *			horizontally. v -- if true, repeat vertically. If nil,
 *			current value is left unchanged.
 * spacing		Spacing vector. The amount of space between repeated
 *			parallax tiles. If nil, current value is left unchanged.
 * flip			Alternate tile flip. Pair of booleans, again:
 *				{flipX, flipY}.
 *			This is useful for sprites that are not tileable in one
 *			or both directions, but look OK when stitched together
 *			with their own mirrored images. If nil, current value
 *			is left unchanged.
 */
static int
SetRepeatPattern(lua_State *L)
{
	Parallax *px;
	int x, y;
	
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TTABLE);
	
	px = lua_touserdata(L, 1);
	L_assert_objtype(L, px, OBJTYPE_PARALLAX);

	/* Get repetition pattern. */
	if (!lua_isnoneornil(L, 2)) {
		L_getstk_boolpair(L, 2, &x, &y);
		px->flags = x ? (px->flags | PX_REPEAT_X) :
		    (px->flags & ~PX_REPEAT_X);
		px->flags = y ? (px->flags | PX_REPEAT_Y) :
		    (px->flags & ~PX_REPEAT_Y);
	}

	if (!lua_isnoneornil(L, 3))
		px->spacing = L_getstk_vect_i(L, 3);

	/* Get alternating flip pattern. */
	if (!lua_isnoneornil(L, 4)) {
		L_getstk_boolpair(L, 2, &x, &y);
		px->flags = x ? (px->flags | PX_ALTERFLIP_X) :
		    (px->flags & ~PX_ALTERFLIP_X);
		px->flags = y ? (px->flags | PX_ALTERFLIP_Y) :
		    (px->flags & ~PX_ALTERFLIP_Y);
	}
	return 0;
}

/*
 * NewBody(world, position) -> body
 *
 * world	World as returned by NewWorld().
 * position	World position vector.
 *
 * Create a body object. Body represents a physical object with position. It
 * owns a list of Shapes, and a list of Tiles (tile = drawing area + sprite
 * list). Anything that has either a physical or graphical representation in the
 * game world is bound to a body object; even cameras and parallax planes have
 * their own body objects.
 */
static int
NewBody(lua_State *L)
{
	vect_f pos;
	Body *body;
	World *world;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TTABLE);

	/* Make sure a valid world is provided. */
	world = lua_touserdata(L, 1);
	L_assert_objtype(L, world, OBJTYPE_WORLD);
	L_assert(L, world->killme == 0, "Dying world");
	
	pos = L_getstk_vect_f(L, 2);
	
	body = body_new(world, pos, BODY_SLEEP);
	lua_pushlightuserdata(L, body);	/* Return Body's address. */
	return 1;
}

/*
 * SetBoundary(camera, boundingBox)
 *
 * camera	Camera object pointer as returned by NewCamera().
 * boundingBox	Bounding box spec: {l=?, r=?, b=?, t=?}. If nil, remove bounds.
 *
 * Restrict camera movement to a bounding box.
 */
static int
SetBoundary(lua_State *L)
{
	Camera *cam;
	BB bb;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	cam = lua_touserdata(L, 1);
	L_assert_objtype(L, cam, OBJTYPE_CAMERA);
	
	if (lua_isnil(L, 2)) {
		bb_init(&bb, 0, 0, 0, 0);
	} else {
		/* Get bounding box from stack. */
		L_getstk_BB(L, 2, &bb);
		L_assert(L, bb_valid(bb), "Invalid bounding box.");
		L_assert(L, cam->size.x <= bb.r-bb.l &&
		    cam->size.y <= bb.t-bb.b, "Bounding box must be bigger "
		    "than camera-visible area size.");
	}

	cam->box = bb;
	return 0;
}

/*
 * SetAttributes(shape, attributes)
 *
 * shape	Shape object as returned by NewShape().
 * attributes	Table of shape attributes:
 * 			{color=?}.
 *		It's OK to omit some or all attributes
 *------------------------------------------------------------------------------
 * Attribute descriptions:
 *
 * color	Change shape color. For debugging purposes only.
 */
static int
set_shape_attr(lua_State *L)
{
	Shape *s;

	s = lua_touserdata(L, 1);
	lua_getfield(L, 2, "color");
	if (!lua_isnil(L, -1)) {
		float color[4];
		L_getstk_color(L, -1, color);
		s->color = color_floatv_to_uint32(color);
	}
	return 0;
}

/*
 * SetAttributes(body, attributes)
 *
 * body		Body object as returned by NewBody().
 * attributes	Table of body attributes:
 * 			{sleep=?}.
 *		It's OK to omit some or all of the attributes.
 *------------------------------------------------------------------------------
 * Attribute descriptions:
 *
 * sleep	Boolean value. If true, body will be put to sleep once it leaves
 *		camera vicinity. A sleeping body will not have its step, timer,
 *		collision functions executed, so it will consume less resources.
 *		Use for optimization if necessary.
 */
static int
set_body_attr(lua_State *L)
{
	Body *body;

	body = lua_touserdata(L, 1);
	lua_getfield(L, 2, "sleep");
	if (!lua_isnil(L, -1)) {
		if (lua_toboolean(L, -1))
			body->flags |= BODY_SLEEP;
		else
			body->flags &= ~BODY_SLEEP;
	}
	return 0;
}

/*
 * SetAttributes(tile, attributes)
 *
 * tile		Tile object as returned by NewTile().
 * attributes	Table of tile attributes:
 * 			{depth=?, flip=?, size=?, color=?}.
 *		It's OK to omit some or all of the attributes.
 *------------------------------------------------------------------------------
 * Attribute descriptions:
 *
 * depth	Integer value that determines drawing order. Into the screen is
 *		negative.
 * flip		Tile can be flipped in either direction. The attribute is a
 *		tuple of boolean values. Four variations are possible:
 * 			{false,false}, {false,true}, {true,false}, {true,true}.
 *		First value determines whether to flip tile horizontally,
 *		second value determines whether to flip tile vertically.
 * size		Tile can be larger or smaller than the sprite that it displays.
 *		Use this attribute to have your tile stretched or shrunk.
 * color	By default, tile has the color {r=1,b=1,g=1,a=1} (opaque white).
 *		You can change it to achieve various transparency/color effects.
 */
static int
set_tile_attr(lua_State *L)
{
	Tile *tile;
	
	tile = lua_touserdata(L, 1);
	lua_getfield(L, 2, "depth");
	if (!lua_isnil(L, -1))
		tile->depth = lua_tonumber(L, -1);
	lua_getfield(L, 2, "angle");
	if (!lua_isnil(L, -1))
		tile->angle = lua_tonumber(L, -1);
	lua_getfield(L, 2, "multiply");
	if (!lua_isnil(L, -1)) {
		if (lua_toboolean(L, -1))
			tile->flags |= TILE_MULTIPLY;
		else
			tile->flags &= ~TILE_MULTIPLY;
	}
	lua_getfield(L, 2, "hidden");
	if (!lua_isnil(L, -1)) {
		if (lua_toboolean(L, -1))
			tile->hidden = 1;
		else
			tile->hidden = 0;
	}
	lua_getfield(L, 2, "flip");
	if (!lua_isnil(L, -1)) {
		int flip_x, flip_y;
		L_getstk_boolpair(L, -1, &flip_x, &flip_y);
		if (flip_x)
			tile->flags |= TILE_FLIP_X;
		else
			tile->flags &= ~TILE_FLIP_X;
		if (flip_y)
			tile->flags |= TILE_FLIP_Y;
		else
			tile->flags &= ~TILE_FLIP_Y;
	}
	lua_getfield(L, 2, "size");
	if (!lua_isnil(L, -1)) {
		tile->size = L_getstk_vect_i(L, -1);
		if (tile->go.stored)
			tile_update_tree(tile);
	}
	lua_getfield(L, 2, "color");
	if (!lua_isnil(L, -1)) {
		float color[4];
		L_getstk_color(L, -1, color);
		tile->color = color_floatv_to_uint32(color);
	}
	return 0;
}

/*
 * SetAttributes(parallax, attributes)
 *
 * parallax	Parallax object as returned by NewParallax().
 * attributes	Table of parallax attributes.
 * 			{offset=?, spacing=?, depth=?, color=?}
 *		It's OK to omit some or all of the attributes.
 *------------------------------------------------------------------------------
 * Attribute descriptions:
 *
 * offset	Offset vector.
 * spacing	Spacing between generated parallax tiles.
 * depth	Integer value that determines drawing order of generated tiles.
 *		Into the screen is negative.
 * color	By default, generated tiles will have the color
 *		{r=1,b=1,g=1,a=1} (opaque white). You can change it to achieve
 *		various transparency/color effects.
 */
static int
set_parallax_attr(lua_State *L)
{
	Parallax *px;

	px = lua_touserdata(L, 1);
	lua_getfield(L, 2, "offset");
	if (!lua_isnil(L, -1))
		px->offset = L_getstk_vect_i(L, -1);
	lua_getfield(L, 2, "spacing");
	if (!lua_isnil(L, -1))
		px->spacing = L_getstk_vect_i(L, -1);
	lua_getfield(L, 2, "depth");
	if (!lua_isnil(L, -1))
		px->depth = lua_tonumber(L, -1);
	lua_getfield(L, 2, "color");
	if (!lua_isnil(L, -1)) {
		float color[4];
		L_getstk_color(L, -1, color);
		px->color = color_floatv_to_uint32(color);
	}
	return 0;
}

/*
 * "Attributes" are considered to be such object properties that are not likely
 * to change each step.
 */
static int
SetAttributes(lua_State *L)
{
	int *objtype;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TTABLE);

	/* Choose a set_?_attr() function depending on object type. */
	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	switch (*objtype) {
	case OBJTYPE_SHAPE: return set_shape_attr(L);
	case OBJTYPE_BODY: return set_body_attr(L);
	case OBJTYPE_TILE: return set_tile_attr(L);
	case OBJTYPE_PARALLAX: return set_parallax_attr(L);
	case OBJTYPE_CAMERA: {
		/* Call set_body_attr() for camera's body. */
		Camera *cam = (Camera *)objtype;
		lua_pushlightuserdata(L, &cam->body);
		lua_replace(L, 1);
		return set_body_attr(L);
	}
	default:
		L_objtype_error(L, *objtype);
	}
	/* NOTREACHED */
}

static void push_color(lua_State *L, uint32_t ucolor) {
	float color[4];
	color_uint32_to_floatv(ucolor, color);
	lua_createtable(L, 0, 4);
	lua_pushnumber(L, color[0]);	/* Red. */
	lua_setfield(L, -2, "r");
	lua_pushnumber(L, color[1]);	/* Green. */
	lua_setfield(L, -2, "g");
	lua_pushnumber(L, color[2]);	/* Blue. */
	lua_setfield(L, -2, "b");
	lua_pushnumber(L, color[3]);	/* Alpha. */
	lua_setfield(L, -2, "a");
	lua_setfield(L, 2, "color");
}

/*
 * GetAttributes(shape) -> attributes
 *
 * Return shape attributes in table form. Presently returned attributes:
 *	{group=?, color=?}.
 */
static int
get_shape_attr(lua_State *L)
{
	Shape *s;
	Group *group;

	s = lua_touserdata(L, 1);
	lua_newtable(L);
	
	/* Find group by inspecting each group until we find one with the same
	   ID as stored in shape. */
	for (group = s->body->world->groups; group != NULL;
	    group = group->hh.next) {
		if (group->id == s->group)
			break;
	}
	assert(group != NULL);	/* Should have been there. */

	push_color(L, s->color);
	
	/* Set group name attribute. */
	lua_pushstring(L, group->name);
	lua_setfield(L, 2, "group");
	
	return 1;
}

/*
 * GetAttributes(body) -> attributes
 *
 * Return body attributes in table form. Presently there are no body attributes
 * that can be retrieved this way.
 */
static int
get_body_attr(lua_State *L)
{
	Body *body;

	body = lua_touserdata(L, 1);
	lua_newtable(L);
	return 1;
}

/*
 * GetAttributes(tile) -> attributes
 *
 * Return tile attributes in table form:
 *	{depth=?, flip={?,?}, color={r=?,g=?,b=?,a=?}}
 */
static int
get_tile_attr(lua_State *L)
{
	Tile *tile;

	tile = lua_touserdata(L, 1);
	lua_createtable(L, 0, 2); /* Two non-array elements. */

	lua_pushnumber(L, tile->depth);
	lua_setfield(L, 2, "depth");
	L_push_boolpair(L, tile->flags & TILE_FLIP_X, tile->flags & TILE_FLIP_Y);
	lua_setfield(L, 2, "flip");

	push_color(L, tile->color);

	return 1;
}

/*
 * GetAttributes(parallax) -> attributes
 *
 * Return parallax attributes in table form:
 *	{offset=?, spacing=?, depth=?, color={r=?,g=?,b=?,a=?}}
 */
static int
get_parallax_attr(lua_State *L)
{
	Parallax *px;

	px = lua_touserdata(L, 1);
	lua_createtable(L, 0, 2); /* Two non-array elements. */

	L_push_vect_i(L, px->offset);
	lua_setfield(L, 2, "offset");
	L_push_vect_i(L, px->spacing);
	lua_setfield(L, 2, "spacing");

	return 1;
}

static int
GetAttributes(lua_State *L)
{
	int *objtype;
	
	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	switch (*objtype) {
	case OBJTYPE_SHAPE: return get_shape_attr(L);
	case OBJTYPE_BODY: return get_body_attr(L);
	case OBJTYPE_TILE: return get_tile_attr(L);
	case OBJTYPE_PARALLAX: return get_parallax_attr(L);
	default:
		L_objtype_error(L, *objtype);
	}
	/* NOTREACHED */
}

/*
 * SetZoom(camera, zoom)
 *
 * camera	Camera object as returned by NewCamera().
 * zoom		Zoom = 1 mean no zoom. More than one zooms in, less than one
 *		zooms out.
 */
static int
SetZoom(lua_State *L)
{
	Camera *cam;
	float zoom;
	
	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TNUMBER);

	cam = lua_touserdata(L, 1);
	zoom = lua_tonumber(L, 2);
	L_assert_objtype(L, cam, OBJTYPE_CAMERA);

	if (zoom < 0.1)
		zoom = 0.1;
	if (zoom > 100.9)
		zoom = 100.9;

	cam->zoom = zoom;
	return 0;
}

/*
 * SetState(valueName, value)
 *
 * Values available for setting:
 *
 * valueName		value range
 * 
 * "drawShapes"		true/false
 * "drawTileTree"	true/false
 * "drawShapeTree"	true/false
 * "outsideView'	true/false
 */
static int
SetState(lua_State *L)
{
	extern int drawShapes, drawTileTree, drawShapeTree, outsideView;
	const char *value_name;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TSTRING);

	value_name = lua_tostring(L, 1);
	if (!strcmp(value_name, "drawShapes"))
		drawShapes = lua_toboolean(L, 2);
	else if (!strcmp(value_name, "drawTileTree"))
		drawTileTree = lua_toboolean(L, 2);
	else if (!strcmp(value_name, "drawShapeTree"))
		drawShapeTree = lua_toboolean(L, 2);
	else if (!strcmp(value_name, "outsideView"))
		outsideView = lua_toboolean(L, 2);

	return 0;
}

/*
 * SetFlags(object, flag1, flag2, .., flagN)
 *
 * Set flags 1 through N for object. The flags must be integers and are simply
 * ORed with the "flags" member of an object.
 */
static int
SetFlags(lua_State *L)
{
	uint flags;
	int i, n, *objtype;

	n = lua_gettop(L);
	L_assert(L, n >= 2, "Not enough arguments.");

	flags = 0;
	for (i = 2; i <= n; i++) {
		luaL_checktype(L, i, LUA_TNUMBER);
		flags |= (uint)lua_tonumber(L, i);
	}

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	switch (*objtype) {
	case OBJTYPE_SHAPE: {
		Shape *shape = (Shape *)objtype;
		shape->flags |= flags;
		break;
	}
	default:
		L_objtype_error(L, *objtype);
	}

	return 0;
}

/*
 * UnsetFlags(object, flag1, flag2, .., flagN)
 *
 * Unset flags 1 through N for an object.
 */
static int
UnsetFlags(lua_State *L)
{
	uint flags;
	int i, n, *objtype;

	n = lua_gettop(L);
	L_assert(L, n >= 2, "Not enough arguments.");

	flags = 0;
	for (i = 2; i <= n; i++) {
		luaL_checktype(L, i, LUA_TNUMBER);
		flags |= (uint)lua_tonumber(L, i);
	}

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	switch (*objtype) {
	case OBJTYPE_SHAPE: {
		Shape *shape = (Shape *)objtype;
		shape->flags &= ~flags;
		break;
	}
	default:
		L_objtype_error(L, *objtype);
	}

	return 0;
}

/*
 * CheckFlags(object, flag1, flag2, .., flagN) -> boolean
 *
 * Make sure that flags 1 through N are all set on object. Returns true if they
 * are, false otherwise.
 */
static int
CheckFlags(lua_State *L)
{
	uint flags;
	int i, n, *objtype;

	n = lua_gettop(L);
	L_assert(L, n >= 2, "Not enough arguments.");

	flags = 0;
	for (i = 2; i <= n; i++) {
		luaL_checktype(L, i, LUA_TNUMBER);
		flags |= (uint)lua_tonumber(L, i);
	}

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	switch (*objtype) {
	case OBJTYPE_SHAPE: {
		Shape *shape = (Shape *)objtype;
		lua_pushboolean(L, shape->flags & flags);
		break;
	}
	default:
		L_objtype_error(L, *objtype);
	}

	return 1;
}

/*
 * GetState(valueName)
 *
 * Values available for getting:
 *
 * valueName		return value range
 *
 * "drawShapes"		true/false
 * "drawTileTree"	true/false
 * "drawShapeTree"	true/false
 * "outsideView'	true/false
 */
static int
GetState(lua_State *L)
{
	extern int drawShapes, drawTileTree, drawShapeTree, outsideView;
	const char *value_name;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TSTRING);

	value_name = lua_tostring(L, 1);
	if (!strcmp(value_name, "drawShapes"))
		lua_pushboolean(L, drawShapes);
	else if (!strcmp(value_name, "drawTileTree"))
		lua_pushboolean(L, drawTileTree);
	else if (!strcmp(value_name, "drawShapeTree"))
		lua_pushboolean(L, drawShapeTree);
	else if (!strcmp(value_name, "outsideView"))
		lua_pushboolean(L, outsideView);

	return 1;
}

/*
 * GetFPS() -> framesPerSecond
 */
static int
GetFPS(lua_State *L)
{
	extern float frames_per_second;
	lua_pushnumber(L, round(frames_per_second));
	return 1;
}

static int
GetBodyCount(lua_State *L)
{
	extern uint iter_body_count;
	lua_pushnumber(L, iter_body_count);
	return 1;
}

/*
 * NewShape(object, relativePos={0,0}, shapeTbl, groupName) -> shape
 *
 * object	Object to attach this shape to. Accepted are either Body objects
 *		or objects that contain bodies (Camera, Parallax).
 * relativePos	Position of shape relative to its body's position.
 * shapeTbl	Depending on what the table contains, a rectangle or circle
 *		shape can be created. See below the two forms.
 * groupName	Name of collision group this shape will belong to.
 *
 * Circle:  {{centerX, centerY}, radius}
 * Rectangle: {l=?, r=?, b=?, t=?}
 */
static int
NewShape(lua_State *L)
{
	extern mem_pool mp_group;
	BB *bb;
	Shape *s;
	Body *body;
	World *world;
	const char *name;
	vect_i offset = {0, 0};
	int n, rc, *objtype;
	Group *group;
	
	/* Basic verification of arguments. */
	n = lua_gettop(L);
	L_assert(L, n == 4, "Invalid number of arguments.");
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 3, LUA_TTABLE);
	luaL_checktype(L, 4, LUA_TSTRING);

	/* Extract body pointer. */
	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	switch (*objtype) {
	case OBJTYPE_BODY: {
		body = (Body *)objtype;
		break;
	}
	case OBJTYPE_CAMERA: {
		body = &((Camera *)objtype)->body;
		break;
	}
	default:
		luaL_error(L, "Invalid object type: %s.",
		    L_objtype_name(*objtype));
	}
	world = body->world;	/* Shorthand for world pointer. */
	
	if (!lua_isnoneornil(L, 2))
		offset = L_getstk_vect_i(L, 2);
	
	/* Get shape off the stack and append to list of shapes. */
	s = shape_new();
	rc = L_getstk_shape(L, 3, offset, s);
	L_assert(L, rc == L_OK, "Couldn't create shape: %s", L_statstr(rc));
	s->body = body;
	DL_APPEND(body->shapes, s);	/* Add to body's shape list. */

	/* Extract collision group name and find corresponding group. */
	name = lua_tostring(L, 4);
	HASH_FIND_STR(world->groups, name, group);
	
	/* Create group if it doesn't exist yet. */
	if (group == NULL) {
		group = mp_alloc(&mp_group);
		L_assert(L, strlen(name) < WORLD_GROUPNAME_LENGTH,
		    "Group name '%s' is too long", name);
		
		/* Set group name, ID, and add it to hash. */
		strcpy(group->name, name);
		group->id = world->next_group_id++;
		L_assert(L, group->id < WORLD_HANDLERS_MAX, "Too many shape "
		    "groups (%i).", group->id);
		HASH_ADD_STR(world->groups, name, group);
	}
	s->group = group->id;	/* Assign group ID to shape. */
	
	/* Set default attribute values. */
	s->color = config.defaultShapeColor;
#if 0
	if (!lua_isnoneornil(L, 5)) {
		/* Call SetAttributes() with the specified attributes. */
		lua_pushcfunction(L, SetAttributes);
		lua_pushlightuserdata(L, s);
		lua_pushvalue(L, 5);
		lua_call(L, 2, 0);
	}
#endif

	/* Add to tree. */
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
		luaL_error(L, "Invalid shape type (%i).", s->shape_type);
	}
	qtree_add(&body->world->shape_tree, &s->go);

	lua_pushlightuserdata(L, s);	/* Return shape pointer. */
	return 1;
}

/*
 * IsValidShape(shapeTbl) -> true/false
 *
 * shapeTbl	Shape specification, see NewShape() for details.
 *
 * Determine if shapeTbl contains a valid shape specification.
 */
static int
IsValidShape(lua_State *L)
{
	Shape shape;
	int rc;
	vect_i zero_offset = {0, 0};

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TTABLE);

	shape_init(&shape);
	rc = L_getstk_shape(L, 1, zero_offset, &shape);
	shape_destroy(&shape);
	lua_pushboolean(L, rc == L_OK);
	return 1;
}

/*
 * SetSpriteList(tile, spriteList, noLookup=false)
 *
 * tile		Tile pointer as returned by NewTile().
 * spriteList	Sprite list pointer as returend by NewSpriteList().
 * noLookup	Boolean value. If true, tile will not be added to quad tree.
 *
 * Set tile's sprite list.
 */
static int
SetSpriteList(lua_State *L)
{
	int i, n, no_lookup;
	Tile *tile;
	SpriteList *sprite_list;
	TexFrag texfrag;
	vect_i tmp, size = {0, 0}, pos;

	n = lua_gettop(L);
	L_assert(L, n >= 2 && n <= 3, "Incorrect number of arguments.");
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);

	tile = lua_touserdata(L, 1);
	sprite_list = lua_touserdata(L, 2);
	tile->sprite_list = sprite_list;
	
	if (lua_isnoneornil(L, 3)) {
		no_lookup = 0;
	} else {
		luaL_checktype(L, 3, LUA_TBOOLEAN);
		no_lookup = lua_toboolean(L, 3);
	}
	
	L_assert_objtype(L, tile, OBJTYPE_TILE);
	L_assert(L, sprite_list == NULL ||
	    sprite_list->objtype == OBJTYPE_SPRITELIST, "SpriteList or nil "
	    "expected (2).");

	/* Reset frame index. */
	tile->frame_index = 0;

	/* Tile bounding box might change. Therefore we remove tile from tree
	   and then re-add it.*/
	if (tile->go.stored)	/* If is stored within space tree. */
		qtree_remove(&tile->body->world->tile_tree, &tile->go);
	
	if (sprite_list == NULL || sprite_list->num_frames == 0)
		return 0; /* No sprites to display, don't add to tree. */
	L_assert(L, sprite_list->tex != NULL, "Sprite list with no texture.");

	/* If tile size is positive, it doesn't depend on sprite size. */
	if (tile->size.x > 0.0) {
		size = tile->size;
	} else {
		/* Traverse sprite list to get max width and max height from
		   which we get a bounding box of such size that it accomodates
		   any sprite in the list. */
		for (i = 0; i < sprite_list->num_frames; i++) {
			/* Get this frame's texture fragment bounding box. */
			texfrag = sprite_list->frames[i];
			L_assert(L,
			    texfrag.r > texfrag.l && texfrag.b > texfrag.t,
			    "Invalid texture fragment for \"%s\": "
			    "{l=%d, r=%d, b=%d, t=%d}.", sprite_list->tex->name,
			    texfrag.l, texfrag.r, texfrag.b, texfrag.t);

			/* Convert from texture coords to pixels. */
			tmp.x = round((texfrag.r -
			    texfrag.l)*sprite_list->tex->pow_w);
			tmp.y = round((texfrag.b -
			    texfrag.t)*sprite_list->tex->pow_h);

			if (tmp.x > size.x)
				size.x = tmp.x;
			if (tmp.y > size.y)
				size.y = tmp.y;
		}

		/* Store this calculated size as negative, so drawing code knows
		   _sprite_ size must be used instead. This negative value will
		   only be used when updating quad tree. */
		tile->size.x = -size.x;
		tile->size.y = -size.y;
	}

	if (no_lookup)
		return 0; /* Argument says it mustn't be added to quad tree. */

	/* Position within world. */
	pos.x = tile->pos.x + round(tile->body->pos.x);
	pos.y = tile->pos.y + round(tile->body->pos.y);
	
	/* Add to tree. */
	bb_init(&tile->go.bb, pos.x, pos.y, pos.x + size.x, pos.y + size.y);
	qtree_add(&tile->body->world->tile_tree, &tile->go);

	return 0;
}

/*
 * TextureToSpriteList(texture, spriteSize) -> spriteList
 *
 * texture	Texture argument (see NewSpriteList for details).
 * spriteSize	Size {w,h} of each sprite.
 *
 * Chop texture into sprites and produce a single SpriteList that contains them
 * all. In the source image sprites are assumed to be ordered left-to-right and
 * top-to-bottom.
 *
 * Returns resulting sprite list.
 */
static int
TextureToSpriteList(lua_State *L)
{
	L_numarg_check(L, 2);
        luaL_checktype(L, 2, LUA_TTABLE);
	
	/* Figure out what the name of the texture is, and try looking it up in
	   the global texture_hash. If not found, create a new texture. */
        char texname[TEXTURE_NAME_MAX];
	texture_spec_parse(L, 1, texname);
	Texture *tex = texture_lookup_or_create(texname);
	
	vect_i size = L_getstk_vect_i(L, 2);
        L_assert(L, size.x > 0 && size.y > 0, "Character size must be positive");
        uint num_cols = tex->w / size.x;        /* Number of columns. */
        uint num_rows = tex->h / size.y;        /* Number of rows. */
	
	/* Create sprite-list frames. */
        uint num_frames = 0;
        TexFrag tmp_frames[200];
        for (uint r = 0; r < num_rows; r++) {
                for (uint c = 0; c < num_cols; c++) {
                        assert(num_frames < sizeof(tmp_frames)/sizeof(tmp_frames[0]));
                        TexFrag *tf = &tmp_frames[num_frames++];
                        tf->l = (float)(c  )*size.x / tex->pow_w;
                        tf->r = (float)(c+1)*size.x / tex->pow_w;
                        tf->b = (float)(r+1)*size.y / tex->pow_h;
                        tf->t = (float)(r  )*size.y / tex->pow_h;
                }
        }
        
        lua_pushlightuserdata(L, spritelist_new(tex, tmp_frames, num_frames));
        return 1;
}

/*
 * Log(msg)
 *
 * Output log message.
 */
static int
Log(lua_State *L)
{
	extern uint64_t game_time;
	const char *str;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TSTRING);
	
	str = lua_tostring(L, 1);
	L_assert(L, strlen(str) < CONSOLE_MAX_LINE_SIZE, "Log message length "
	    "(%) exceeds limit (%i).", strlen(str), CONSOLE_MAX_LINE_SIZE);
	
	/* Copy string into (next) console line buffer. */
	console.last_line = (console.last_line + 1) % CONSOLE_MAX_LINES;
	strcpy(console.buffer[console.last_line], str);
	console.log_time[console.last_line] = game_time; /* Save log time. */
	
	return 0;
}

/*
 * SetFrame(tile, frameNumber)
 *
 * tile		Tile object as returned by NewTile().
 * frameNumber	Index into a tile's sprite list.
 *
 * Select frame.
 */
static int
SetFrame(lua_State *L)
{
	int new_index;
	Tile *tile;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TNUMBER);

	tile = lua_touserdata(L, 1);
	L_assert_objtype(L, tile, OBJTYPE_TILE);
	L_assert(L, tile->sprite_list != NULL, "Tile has no sprite list.");
	L_assert(L, tile->anim_type == TILE_ANIM_NONE, "Use "
	    "eapi.StopAnimation() to stop ongoing animation before setting "
	    "frames manually.");
	new_index = lua_tointeger(L, 2);
	L_assert(L, new_index >= 0 && new_index < tile->sprite_list->num_frames,
	    "Frame number out of range.");
	tile->frame_index = new_index;
	return 0;
}

/*
 * SetFrameLoop(tile, frameNumber)
 *
 * tile		Tile object as returned by NewTile().
 * frameNumber	Index into a tile's sprite list.
 *
 * Exactly like SetFrame() except if frame number falls outside valid range, it
 * is adjusted like so:
 *	actualFrame = frameNumber modulo numFrames
 */
static int
SetFrameLoop(lua_State *L)
{
	int new_index;
	Tile *tile;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TNUMBER);
	
	tile = lua_touserdata(L, 1);
	L_assert_objtype(L, tile, OBJTYPE_TILE);
	L_assert(L, tile->sprite_list != NULL, "Tile has no sprite list.");
	L_assert(L, tile->sprite_list->num_frames > 0, "Sprite list has no frames.");
	L_assert(L, tile->anim_type == TILE_ANIM_NONE, "Use "
	    "eapi.StopAnimation() to stop ongoing animation before setting "
	    "frames manually.");
	new_index = lua_tointeger(L, 2);
	
	/* Careful with modulus operator being system-dependent for negative
	   operands. */
	if (new_index >= 0)
		new_index %= tile->sprite_list->num_frames;
	else {
		new_index = tile->sprite_list->num_frames -
		    ((-new_index) % tile->sprite_list->num_frames);
	}
	
	tile->frame_index = new_index;	
	return 0;
}

/*
 * SetFrameClamp(tile, frameNumber)
 *
 * tile		Tile object as returned by NewTile().
 * frameNumber	Index into a tile's sprite list.
 *
 * Exactly like SetFrame() except if frame number falls outside valid range, it
 * is adjusted like so:
 * 	if frameNumber < 0 then frameNumber = 0
 *	if frameNumber >= numFrames then frameNumber = numFrames - 1
 */
static int
SetFrameClamp(lua_State *L)
{
	int new_index;
	Tile *tile;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TNUMBER);
	
	tile = lua_touserdata(L, 1);
	L_assert_objtype(L, tile, OBJTYPE_TILE);
	L_assert(L, tile->sprite_list != NULL, "Tile has no sprite list.");
	L_assert(L, tile->anim_type == TILE_ANIM_NONE, "Use "
	    "eapi.StopAnimation() to stop ongoing animation before setting "
	    "frames manually.");
	new_index = lua_tointeger(L, 2);
	
	if (new_index < 0)
		new_index = 0;
	else if (new_index >= tile->sprite_list->num_frames)
		new_index = tile->sprite_list->num_frames - 1;
	
	tile->frame_index = new_index;	
	return 0;
}

/*
 * SetFrameLast(tile)
 *
 * Draw last frame from tile's sprite list.
 */
static int
SetFrameLast(lua_State *L)
{
	Tile *tile;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	
	tile = lua_touserdata(L, 1);
	L_assert_objtype(L, tile, OBJTYPE_TILE);
	L_assert(L, tile->sprite_list != NULL, "Tile has no sprite list.");
	L_assert(L, tile->anim_type == TILE_ANIM_NONE, "Use "
	    "eapi.StopAnimation() to stop ongoing animation before setting "
	    "frames manually.");
	
	tile->frame_index = tile->sprite_list->num_frames - 1;	
	return 0;
}

/*
 * SetGameSpeed(speed)
 *
 * speed        Integer value. 0 and 1 is regular real-time speed.
 *              Negative values slow the game down. Positive values speed it up.
 *
 * Change game speed.
 */
static int
SetGameSpeed(lua_State *L)
{
        L_numarg_check(L, 1);
        luaL_checktype(L, 1, LUA_TNUMBER);
        
        config.gameSpeed = lua_tonumber(L, 1);
        
        return 0;
}

/*
 * Animate(obj, animType, FPS, startTime=0)
 *
 * obj		Tile or Parallax object.
 * animType	Defines what happens when animation runs past the last (or the
 *		first) frame. Possible values:
 *		ANIM_LOOP: Looping animation. Once the last (first) frame is
 *			   reached, animation starts from first (last) frame.
 *		ANIM_CLAMP: Once the last (or if FPS is negative, first) frame
 *			    is reached, animation stops there.
 * 		ANIM_REVERSE: Once the last frame is reached, animation starts
 *			      going backwards. Then when first frame is reached,
 *			      it starts going forward again. And so on.
 * FPS		Animation speed: frames per second. If negative, animation is
 *		assumed to start from last frame and go backwards.
 * startTime	When to assume the animation started, in seconds relative to
 *		current world time.
 *
 * Do simple tile animation: go through all frames of tile's sprite list at
 * the rate of FPS. There's no overhead for the engine to simply calculate which
 * frame should be drawn at any particual time. For the scripts to set the
 * correct frame each step or whenever some timer is called can be a
 * considerable slowdown however. Therefore if possible, use this simple way of
 * animating a tile rather than doing it from the script manually.
 */
static int
Animate(lua_State *L)
{
	enum TileAnimType *anim_type;
	int n, *objtype;
	double *fps, *start_time;
	World *world;

	n = lua_gettop(L);
	L_assert(L, n >= 3 && n <= 4, "Invalid number of arguments.");
	
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	switch (*objtype) {
	case OBJTYPE_TILE: {
		Tile *tile = (Tile *)objtype;
		world = tile->body->world;
		anim_type = &tile->anim_type;
		fps = &tile->anim_FPS;
		start_time = &tile->anim_start;
		break;
	}
	case OBJTYPE_PARALLAX: {
		Parallax *px = (Parallax *)objtype;
		world = px->body.world;
		anim_type = &px->anim_type;
		fps = &px->anim_FPS;
		start_time = &px->anim_start;
		break;
	}
	default:
		luaL_error(L, "Invalid object type (%s).",
		    L_objtype_name(*objtype));
	}
	
	luaL_checktype(L, 2, LUA_TNUMBER);
	*anim_type = lua_tonumber(L, 2);
	L_assert(L, *anim_type == TILE_ANIM_LOOP ||
	    *anim_type == TILE_ANIM_CLAMP || *anim_type == TILE_ANIM_REVERSE,
	    "Invalid animation type (%i).", *anim_type);
	
	luaL_checktype(L, 3, LUA_TNUMBER);
	*fps = lua_tonumber(L, 3);
	
	*start_time = world->step * world->step_sec;
	if (!lua_isnoneornil(L, 4)) {
		luaL_checktype(L, 4, LUA_TNUMBER);
		*start_time += lua_tonumber(L, 4);
	}
	
	return 0;
}

/*
 * StopAnimation(obj)
 *
 * obj		Tile or Parallax object.
 *
 * Stop tile animation by setting anim_type to ANIM_NONE.
 */
static int
StopAnimation(lua_State *L)
{
	int *objtype;
	World *world;

	L_numarg_check(L, 1);
	
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	switch (*objtype) {
	case OBJTYPE_TILE: {
		Tile *tile = (Tile *)objtype;
		world = tile->body->world;
		tile->anim_type = TILE_ANIM_NONE;
		break;
	}
	case OBJTYPE_PARALLAX: {
		Parallax *px = (Parallax *)objtype;
		world = px->body.world;
		px->anim_type = TILE_ANIM_NONE;
		break;
	}
	default:
		luaL_error(L, "Invalid object type (%s).",
		    L_objtype_name(*objtype));
	}
	
	return 0;
}

/*
 * SetAnimPos(tile, animPos)
 *
 * tile		Tile object (as returned by NewTile()) or Parallax object (as
 *		returned by NewParallax()).
 * animPos	See below.
 *
 * Set tile animation position. animPos is used to calculate the current frame
 * number. As it goes from 0.0 to 1.0, each frame in the animation will be
 * shown. Once it reaches 1.0, however, the animation starts repeating.
 */
static int
SetAnimPos(lua_State *L)
{
	double anim_pos;
	int num_frames, *frame_index, *objtype, new_index;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TNUMBER);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	switch (*objtype) {
	case OBJTYPE_TILE: {
		Tile *tile = (Tile *)objtype;
		assert(tile->sprite_list && tile->sprite_list->num_frames > 0);
		num_frames = tile->sprite_list->num_frames;
		frame_index = &tile->frame_index;
		break;
	}
	case OBJTYPE_PARALLAX: {
		Parallax *px = (Parallax *)objtype;
		num_frames = px->sprite_list->num_frames;
		frame_index = &px->frame_index;
		break;
	}
	default:
		L_objtype_error(L, *objtype);
	}
	
	anim_pos = lua_tonumber(L, 2);
	anim_pos -= floor(anim_pos);
	new_index = floor(anim_pos * (num_frames - 1));
	*frame_index = new_index;
	return 0;
}

/*
 * SetPos(object, pos)
 *
 * object	Accepted objects: Body, Camera, Tile.
 *		Also shapes are accepted, but act a bit differently. Since there
 *		is no explicit position relative to owner Body, this position is
 *		added to the shape's current "position".
 * pos		Position vector.
 *
 * Change position of something. If object is a Tile, then only its relative
 * position is altered (with respect to the body that owns the Tile).
 */
static int
SetPos(lua_State *L)
{
	int *objtype;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TTABLE);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	
	switch (*objtype) {
	case OBJTYPE_BODY: {
		Body *body = (Body *)objtype;
		body_set_pos(body, L_getstk_vect_f(L, 2));
		break;
	}
	case OBJTYPE_CAMERA: {
		Camera *cam = (Camera *)objtype;
		cam_set_pos(cam, L_getstk_vect_f(L, 2));
		break;
	}
	case OBJTYPE_TILE: {
		Tile *tile = (Tile *)objtype;
		tile->pos = L_getstk_vect_i(L, 2);
		tile_update_tree(tile);
		break;
	}
	case OBJTYPE_SHAPE: {
		Shape *s = (Shape *)objtype;
		vect_i delta = L_getstk_vect_i(L, 2);
		
		assert(s->shape_type == SHAPE_RECTANGLE);
		s->shape.rect.l += delta.x;
		s->shape.rect.r += delta.x;
		s->shape.rect.b += delta.y;
		s->shape.rect.t += delta.y;
		shape_update_tree(s);
		break;
	}
	default:
		L_objtype_error(L, *objtype);
	}
	return 0;
}

/*
 * SetVel(body, velocity)
 */
static int
SetBodyData(lua_State *L, void(*setter)(Body*, vect_f))
{
	int *objtype;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TTABLE);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	
	if (*objtype == OBJTYPE_BODY) {
		Body *body = (Body *) objtype;
		setter(body, L_getstk_vect_f(L, 2));
		body->cPhys = 1;
	}
	else {
		L_objtype_error(L, *objtype);
	}
	return 0;
}

static void SetBodyVel(Body *body, vect_f data) {
    body->vel = data;
}

static void SetBodyGravity(Body *body, vect_f data) {
    body->gravity = data;
}

static int
SetVel(lua_State *L) {
    return SetBodyData(L, &SetBodyVel);
}

static int
SetGravity(lua_State *L) {
    return SetBodyData(L, &SetBodyGravity);
}

static void SetVelDataX(Body *body, double data) {
    body->vel.x = data;
}

static void SetVelDataY(Body *body, double data) {
    body->vel.y = data;
}

static int
SetVelData(lua_State *L, void(*setter)(Body*, double))
{
	int *objtype;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TNUMBER);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	
	if (*objtype == OBJTYPE_BODY) {
		Body *body = (Body *) objtype;
		setter(body, L_getstk_double(L, 2));
		body->cPhys = 1;
	}
	else {
		L_objtype_error(L, *objtype);
	}
	return 0;
}

static int
SetVelX(lua_State *L) {
    return SetVelData(L, &SetVelDataX);
}

static int
SetVelY(lua_State *L) {
    return SetVelData(L, &SetVelDataY);
}

/*
 * SetBackgroundColor(world, color)
 *
 * world	World as returned by NewWorld().
 * color	Color: {r=?, g=?, b=?, a=?}.
 *
 * Set world background color (a quad is always drawn in the background of each
 * world).
 */
static int
SetBackgroundColor(lua_State *L)
{
	float color[4];
	World *world;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TTABLE);

	L_getstk_color(L, 2, color);
	world = lua_touserdata(L, 1);
	L_assert_objtype(L, world, OBJTYPE_WORLD);
	L_assert(L, world->killme == 0, "Dying world");
	
	memcpy(world->bg_color, color, sizeof(world->bg_color));
	return 0;
}

/*
 * GetBody(shape) -> body
 * GetBody(tile) -> body
 *
 * shape	Shape object as returned by NewShape().
 * tile		Tile object as returned by NewTile().
 *
 * Return a shape's body.
 */
static int
GetBody(lua_State *L)
{
	int *objtype;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	
	objtype = lua_touserdata(L, 1);
	switch (*objtype) {
	case OBJTYPE_SHAPE: {
		Shape *s = (Shape *)objtype;
		lua_pushlightuserdata(L, s->body);
		break;
	}
	case OBJTYPE_TILE: {
		Tile *t = (Tile *)objtype;
		lua_pushlightuserdata(L, t->body);
		break;
	}
	default:
		luaL_error(L, "Object type %s not supported.",
		    L_objtype_name(*objtype));
	}
	return 1;
}

/*
 * GetStaticBody(world) -> staticBody
 *
 * world	World as returned by NewWorld().
 *
 * Get the one and only static body that world has (its static_body
 * member). Static body is a special Body object whose cpBody is not added to
 * Chipmunk space, and is therefore not affected by gravity, collisions etc.
 * It has infinite mass and infinite moment of inertia, its position is always
 * at the origin (0,0). Any shape added to it becomes a static shape (optimized
 * collision detection).
 */
static int
GetStaticBody(lua_State *L)
{
	World *world;
	
	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	
	world = lua_touserdata(L, 1);
	L_assert_objtype(L, world, OBJTYPE_WORLD);
	L_assert(L, world->killme == 0, "Dying world");

	lua_pushlightuserdata(L, &world->static_body);
	return 1;
}

/*
 * GetWorld(object) -> world
 *
 * Get the world that object belongs to. If object is a world itself, return it.
 */
static int
GetWorld(lua_State *L)
{
	int *objtype;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	switch (*objtype) {
	case OBJTYPE_BODY: {
		Body *body = (Body *)objtype;
		lua_pushlightuserdata(L, body->world);
		break;
	}
	case OBJTYPE_SHAPE: {
		Shape *shape = (Shape *)objtype;
		Body *body = shape->body;
		lua_pushlightuserdata(L, body->world);
		break;
	}
	case OBJTYPE_CAMERA: {
		Camera *cam = (Camera *)objtype;
		lua_pushlightuserdata(L, cam->body.world);
		break;
	}
	case OBJTYPE_WORLD: {
		lua_pushlightuserdata(L, objtype);
		break;
	}
	default:
		luaL_error(L, "Object type %s not supported.",
		    L_objtype_name(*objtype));
	}
	return 1;
}

/*
 * __SetStepFunc(object, stepFuncID, afterStepFuncID)
 *
 * object		Accepted objects: Body, Camera, Parallax.
 * stepFuncID		Step function ID.
 * afterStepFuncID	After-step function ID.
 *
 * Set the step and after-step functions of an object. Since in the API we
 * accept only function IDs that index eapi.__idToObjectMap table, this API
 * function shouldn't be invoked directly by scripts but rather through the
 * simplified interfaces in eapi.lua.
 * Setting object's step function to zero will effectively remove it.
 */
static int
__SetStepFunc(lua_State *L)
{
	int *objtype;
	Body *body;

	L_numarg_check(L, 3);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TNUMBER);
	luaL_checktype(L, 3, LUA_TNUMBER);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	
	switch (*objtype) {
	case OBJTYPE_BODY: {
		body = lua_touserdata(L, 1);
		break;
	}
	case OBJTYPE_CAMERA: {
		Camera *cam = lua_touserdata(L, 1);
		body = &cam->body;
		break;
	}
	case OBJTYPE_PARALLAX: {
		Parallax *px = lua_touserdata(L, 1);
		body = &px->body;
		break;
	}
	default:
		L_objtype_error(L, *objtype);
	}
	
	body->step_func_id = lua_tonumber(L, 2);
	body->afterstep_func_id = lua_tonumber(L, 3);
	return 0;
}

/*
 * __GetStepFunc(object) -> stepFuncID, afterStepFuncID
 *
 * object	Accepted objects: Body, Camera, Parallax.
 *
 * Get the step and after-step function IDs from a body or from a body
 * containing object.
 */
static int
__GetStepFunc(lua_State *L)
{
	int *objtype;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");

	switch (*objtype) {
	case OBJTYPE_BODY: {
		Body *body = lua_touserdata(L, 1);
		lua_pushnumber(L, body->step_func_id);
		lua_pushnumber(L, body->afterstep_func_id);
		break;
	}
	case OBJTYPE_CAMERA: {
		Camera *cam = lua_touserdata(L, 1);
		lua_pushnumber(L, cam->body.step_func_id);
		lua_pushnumber(L, cam->body.afterstep_func_id);
		break;
	}
	case OBJTYPE_PARALLAX: {
		Parallax *px = lua_touserdata(L, 1);
		lua_pushnumber(L, px->body.step_func_id);
		lua_pushnumber(L, px->body.afterstep_func_id);
		break;
	}
	default:
		L_objtype_error(L, *objtype);
	}
	return 2;
}

/*
 * GetDeltaPos(object) -> {x=?, y=?}
 *
 * object	Body object pointer.
 *
 * Return the position delta that object moved from previous step to the current
 * step.
 */
static int
GetDeltaPos(lua_State *L)
{
	int *objtype;
	vect_i delta;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	
	switch (*objtype) {
	case OBJTYPE_BODY: {
		Body *body = lua_touserdata(L, 1);
		
		/* Note that we return actual changes in (rounded) position
		   values. */
		delta.x = round(body->pos.x) - round(body->prevstep_pos.x);
		delta.y = round(body->pos.y) - round(body->prevstep_pos.y);
		break;
	}
	default:
		L_objtype_error(L, *objtype);
	}
	L_push_vect_i(L, delta);
	return 1;
}

/*
 * GetSize(something) -> {x=?, y=?}
 *
 * Get the size of something. To get the size of a texture, pass in the same
 * kind of argument you would give to NewSpriteList().
 */
static int
GetSize(lua_State *L)
{
	int *objtype;

	L_numarg_check(L, 1);
	if (lua_type(L, 1) == LUA_TLIGHTUSERDATA) {
		objtype = lua_touserdata(L, 1);
		L_assert(L, objtype != NULL, "NULL pointer!");
		switch (*objtype) {
		case OBJTYPE_CAMERA: {
			vect_f sz;
			Camera *cam = (Camera *)objtype;
			sz.x = round(cam->size.x / cam->zoom);
			sz.y = round(cam->size.y / cam->zoom);
			L_push_vect_f(L, sz);
			break;
		}
		case OBJTYPE_TILE: {
			Tile *tile = (Tile *)objtype;
			SpriteList *sprite_list = tile->sprite_list;
			vect_i size = tile->size;
			
			/* Update tile frame index before using it. */
			tile_update_frameindex(tile);
			
			assert(sprite_list != NULL);
			
			/* Tile size calculation ripped from draw_sprite(). */
			TexFrag texfrag = tile->sprite_list->frames[tile->frame_index];
			assert(texfrag.r > texfrag.l && texfrag.b > texfrag.t);
			if (size.x < 0.0) { /* If size is negative, use sprite size. */
				size.x = round((texfrag.r - texfrag.l)*sprite_list->tex->pow_w);
				size.y = round((texfrag.b - texfrag.t)*sprite_list->tex->pow_h);
			}
			
			L_push_vect_i(L, size);
			break;
		}
		case OBJTYPE_SPRITELIST: {
			SpriteList *sprite_list = (SpriteList *)objtype;
			vect_i size = {0, 0}, tmp = {0, 0};
			TexFrag texfrag;
			
			/* Compute smallest size that contains all frames. */
			for (int i = 0; i < sprite_list->num_frames; i++) {
				texfrag = sprite_list->frames[i];
				
				/* Convert from texture coords to pixels. */
				tmp.x = round((texfrag.r -
				    texfrag.l)*sprite_list->tex->pow_w);
				tmp.y = round((texfrag.b -
				    texfrag.t)*sprite_list->tex->pow_h);
				
				if (tmp.x > size.x)
					size.x = tmp.x;
				if (tmp.y > size.y)
					size.y = tmp.y;
			}
			L_push_vect_i(L, size);
			break;
		}
		default:
			luaL_error(L, "Invalid object type: %s.",
			L_objtype_name(*objtype));
		}
	} else {
		Texture *tex;
		char texname[TEXTURE_NAME_MAX];
		
		/* Figure out what the name of the texture is, and try looking
		   it up in the global texture_hash. If not found, create a new
		   texture. */
		texture_spec_parse(L, 1, texname);
		tex = texture_lookup_or_create(texname);
		L_push_vect_f(L, vect_f_new(tex->w, tex->h));
	}
	return 1;
}

/*
 * GetTime(object) -> seconds
 *
 * object	World object, or any other object from which the world
 *		that it belongs to can be extracted.
 *
 * Get world time.
 */
static int
GetTime(lua_State *L)
{
	int *objtype;
	World *world;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	switch (*objtype) {
	case OBJTYPE_WORLD: {
		world = (World *)objtype;
		break;
	}
	case OBJTYPE_BODY: {
		Body *body = (Body *)objtype;
		world = body->world;
		break;
	}
	case OBJTYPE_CAMERA: {
		Body *body = &((Camera *)objtype)->body;
		world = body->world;
		break;
	}
	case OBJTYPE_SHAPE: {
		Shape *shape = (Shape *)objtype;
		Body *body = shape->body;
		world = body->world;
		break;
	}
	case OBJTYPE_TILE: {
		Tile *tile = (Tile *)objtype;
		world = tile->body->world;
		break;
	}
	default:
		luaL_error(L, "Invalid object type: %s.",
		    L_objtype_name(*objtype));
	}
	L_assert(L, world->killme == 0, "Dying world");
	
	/* Now = (current step number) * (step duration in seconds) */
	lua_pushnumber(L, world->step * world->step_sec);
	return 1;
}

/*
 * NewTile(object, pos={0,0}, size=nil, spriteList, depth) -> tile
 *
 * object		Object the tile will be attached to. Presently accepted
 *			objects: Body and Camera.
 * pos			Tile position (lower left corner) relative to object's
 *			position.
 * size			Tile size. If nil, sprite (current frame) dimensions are
 *			used.
 * spriteList		Sprite list pointer as returned by NewSpriteList(). May
 *			be nil, in which case there will be nothing to display.
 * depth		Depth determines drawing order. Into the screen is
 *			negative.
 */
static int
NewTile(lua_State *L)
{
	int *objtype;
	float depth;
	vect_i pos = {0,0}, size = {0,0};
	SpriteList *sprite_list;
	Tile *tile;
	Body *body;

	L_numarg_check(L, 5);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 4, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 5, LUA_TNUMBER);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "Expected Body or Camera.");
	switch (*objtype) {
	case OBJTYPE_BODY:
		body = (Body *)objtype;
		break;
	case OBJTYPE_CAMERA:
		body = &((Camera *)objtype)->body;
		break;
	default:
		luaL_error(L, "Invalid object type: %s.",
		    L_objtype_name(*objtype));
	}
	if (!lua_isnoneornil(L, 2)) {
		luaL_checktype(L, 2, LUA_TTABLE);
		pos = L_getstk_vect_i(L, 2);
	}
	if (!lua_isnoneornil(L, 3)) {
		luaL_checktype(L, 3, LUA_TTABLE);
		size = L_getstk_vect_i(L, 3);
	}
	sprite_list = lua_touserdata(L, 4);
	depth = lua_tonumber(L, 5);
	L_assert(L, (size.x == 0 && size.y == 0) ||
	    (size.x > 0.0 && size.y > 0.0),"Tile dimensions must be positive.");

	/* Create the tile. */
	tile = tile_new(body, pos, size, sprite_list, depth);

	/* Call SetSpriteList(tile, sprite_list, noLookup). */
	lua_pushcfunction(L, SetSpriteList);
	lua_pushlightuserdata(L, tile);
	lua_pushlightuserdata(L, sprite_list);
	/* NOTE: Camera tiles are always visible; don't add them to quad tree.*/
	lua_pushboolean(L, *objtype == OBJTYPE_CAMERA);
	lua_call(L, 3, 0);

	lua_pushlightuserdata(L, tile);		/* Return tile address. */
	return 1;
}

/*
 * GetPos(body) -> {x=?, y=?}
 * Return Body (world) position.
 *
 * GetPos(camera) -> {x=?, y=?}
 * Return Camera (world) position.
 *
 * GetPos(tile) -> {x=?, y=?}
 * Return Tile offset (relative to Body that owns it).
 */
static int
GetPos(lua_State *L)
{
	int *objtype;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	
	switch (*objtype) {
	case OBJTYPE_BODY: {
		Body *body = (Body *)objtype;
		L_push_vect_f(L, body->pos);
		break;
	}
	case OBJTYPE_CAMERA: {
		Camera *cam = (Camera *)objtype;
		L_push_vect_f(L, cam->body.pos);
		break;
	}
	case OBJTYPE_TILE: {
		Tile *tile = (Tile *)objtype;
		L_push_vect_i(L, tile->pos);
		break;
	}
	default:
		L_objtype_error(L, *objtype);
	}
	return 1;
}

static int
GetVel(lua_State *L) {
	int *objtype;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	
	if (*objtype == OBJTYPE_BODY) {
		L_push_vect_f(L, ((Body *)objtype)->vel);
	}
	else {
		L_objtype_error(L, *objtype);
	}
	return 1;
}

/*
 * GetData(obj) -> {...}
 *
 * obj		Supported objects: Body, Shape, World, Camera.
 *
 * Return a table containing data about object.
 */
static int
GetData(lua_State *L)
{
	int *objtype;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	
	switch (*objtype) {
	case OBJTYPE_BODY: {
		L_push_bodyData(L, (Body *)objtype, (Body *)objtype);
		break;
	}
	case OBJTYPE_SHAPE: {
		L_push_shapeData(L, (Shape *)objtype);
		break;
	}
	case OBJTYPE_CAMERA: {
		L_push_camData(L, (Camera *)objtype);
		break;
	}
	case OBJTYPE_WORLD: {
		L_push_worldData(L, (World *)objtype);
		break;
	}
	default:
		L_objtype_error(L, *objtype);
	}
	return 1;
}

/*
 * Link(child, parent)
 *
 * child, parent	Body objects as returned by NewBody().
 *
 * Attach child to parent. This child-parent connection has no meaning outside
 * of what the script decides to do with it.
 *	* To "unlink", call eapi.Unlink().
 *	* To get a list of attached children , call eapi.GetChildren(parent).
 *	* To get a child's parent, call eapi.GetParent(child).
 */
static int
Link(lua_State *L)
{
	int i;
	Body *child, *parent;

	L_numarg_check(L, 2);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);

	child = lua_touserdata(L, 1);
	parent = lua_touserdata(L, 2);
	L_assert_objtype(L, child, OBJTYPE_BODY);
	L_assert_objtype(L, parent, OBJTYPE_BODY);

	if (child->parent == parent)
		return 0;	/* Already linked. */

	/* Set parent as child's parent, and add child to parent's child list.*/
	child->parent = parent;
	for (i = 0; i < BODY_CHILDREN_MAX; i++) {
		assert(parent->children[i] != child);
		if (parent->children[i] == NULL)
			break;	/* Found a free spot. */
	}
	assert(i != BODY_CHILDREN_MAX);
	parent->children[i] = child;
	
	return 0;
}

/*
 * Unlink(body)
 *
 * Detach body from its parent (if it has one). See Link() for more details.
 */
static int
Unlink(lua_State *L)
{
	int i;
	Body *body;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	body = lua_touserdata(L, 1);
	L_assert_objtype(L, body, OBJTYPE_BODY);

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
	return 0;
}

/*
 * GetParent(object) -> object
 *
 * Get the object that this object is linked to. nil if it's not linked to
 * anything.
 */
static int
GetParentFunc(lua_State *L)
{
	Body *body;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	body = lua_touserdata(L, 1);
	L_assert_objtype(L, body, OBJTYPE_BODY);
	if (body->parent == NULL)
		lua_pushnil(L);
	else
		lua_pushlightuserdata(L, body->parent);
	return 1;
}

/*
 * GetChildren(object) -> object
 *
 * Get linked children. The return value is an array (table with numeric
 * indices) of pointers to bodies that have been previously linked using the
 * Link() function.
 */
static int
GetChildren(lua_State *L)
{
	int i, key;
	Body *body;

	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);

	body = lua_touserdata(L, 1);
	L_assert_objtype(L, body, OBJTYPE_BODY);

	/* Create and return an array of lightuserdata pointers to children. */
	lua_newtable(L);
	key = 1;
	for (i = 0; i < BODY_CHILDREN_MAX; i++) {
		if (body->children[i] == NULL)
			continue;
		lua_pushinteger(L, key++);
		lua_pushlightuserdata(L, body->children[i]);
		lua_settable(L, -3);
	}
	return 1;
}

/*
 * __NewTimer(world, when, functionID) -> timer
 * __NewTimer(body, when, functionID) -> timer
 *
 * world	World as returned by NewWorld().
 * body		Body as returned by NewBody().
 * when		When to execute the timer.
 * functionID	Index into eapi.__idToObjectMap.
 *
 * Create a timer.
 */
static int
__NewTimer(lua_State *L)
{
	int func_id, *objtype;
	double when;
	Timer *timer;

	L_numarg_check(L, 3);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TNUMBER);
	luaL_checktype(L, 3, LUA_TNUMBER);

	when = lua_tonumber(L, 2);
	func_id = lua_tonumber(L, 3);
	L_assert(L, func_id > 0, "Function ID must be positive (func_id: %i).",
	    func_id);

	objtype = lua_touserdata(L, 1);
	L_assert(L, objtype != NULL, "NULL object pointer.");
	switch (*objtype) {
	case OBJTYPE_WORLD: {
		World *world = (World *)objtype;
		L_assert(L, world->killme == 0, "Dying world");
#ifndef NDEBUG
		double now = world->step * world->step_sec;
		L_assert(L, when >= now,
		    "Adding timers with [timestamp < now] not allowed.");
		int i;
		for (i = 0; i < WORLD_TIMERS_MAX; i++) {
			if (world->timers[i].func_id == 0)
				break;
		}
		L_assert(L, i != WORLD_TIMERS_MAX, "All timer slots for this "
		    "world are already filled (%d).", WORLD_TIMERS_MAX);
#endif
		timer = world_add_timer(world, when, func_id);
		break;
	}
	case OBJTYPE_BODY: {
		Body *body = (Body *)objtype;
#ifndef NDEBUG
		double now = body->world->step * body->world->step_sec;
		L_assert(L, when >= now,
		    "Adding timers with [timestamp < now] not allowed.");
		int i;
		for (i = 0; i < BODY_TIMERS_MAX; i++) {
			if (body->timers[i].func_id == 0)
				break;
		}
		L_assert(L, i != BODY_TIMERS_MAX, "All timer slots for this "
		    "body are already filled (%d).", BODY_TIMERS_MAX);
#endif
		timer = body_add_timer(body, when, func_id);
		break;
	}
	case OBJTYPE_CAMERA: {
		Camera *cam = (Camera *)objtype;
		Body *body = &cam->body;
#ifndef NDEBUG
		double now = body->world->step * body->world->step_sec;
		L_assert(L, when >= now,
		    "Adding timers with [timestamp < now] not allowed.");
		int i;
		for (i = 0; i < BODY_TIMERS_MAX; i++) {
			if (body->timers[i].func_id == 0)
				break;
		}
		L_assert(L, i != BODY_TIMERS_MAX, "All timer slots for this "
		    "camera are already filled (%d).", BODY_TIMERS_MAX);
#endif
		timer = body_add_timer(body, when, func_id);
		break;
	}
	default:
		luaL_error(L, "Invalid object type: %s.",
		    L_objtype_name(*objtype));
	}

	lua_pushlightuserdata(L, timer);
	return 1;
}

/*
 * RemoveTimer(object, timerID)
 */
static int
RemoveTimer(lua_State *L)
{
	Timer *timer;
	
	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	timer = lua_touserdata(L, 1);
	L_assert_objtype(L, timer, OBJTYPE_TIMER);
	assert(timer != NULL && timer->objtype == OBJTYPE_TIMER &&
	    timer->func_id > 0 && timer->id >= 0 && timer->owner != NULL);

#ifndef NDEBUG
	switch (*(int *)timer->owner) {
	case OBJTYPE_WORLD: {
		World *world = (World *)timer->owner;
		
		assert(timer->id < WORLD_TIMERS_MAX);
		assert(timer >= world->timers &&
		    timer < world->timers + sizeof(Timer)*WORLD_TIMERS_MAX);
		break;
	}
	case OBJTYPE_BODY: {
		Body *body = (Body *)timer->owner;
		
		assert(timer->id < BODY_TIMERS_MAX);
		assert(timer >= body->timers &&
		    timer < body->timers + sizeof(Timer)*BODY_TIMERS_MAX);
		break;
	}
	}
#endif /* Debug mode. */

	/* Removal is easy! */
	memset(timer, 0, sizeof(Timer));
	return 0;
}

/*
 * Dump(shape, prefix="") -> Lua code
 *
 * Produce Lua code that creates the argument shape.
 */
static int
Dump(lua_State *L)
{
	Shape *s;
	Body *body;
	vect_i v;
	BB bb;
	String dump, tmp;
	Group *group;

	s = lua_touserdata(L, 1);
	L_assert_objtype(L, s, OBJTYPE_SHAPE);
	body = s->body;
	L_assert_objtype(L, body, OBJTYPE_BODY);

        const char *prefix = "";
        if (!lua_isnoneornil(L, 2))
                prefix = lua_tostring(L, 2);

	str_init(&dump);
	str_init(&tmp);
        str_append_cstr(&dump, prefix);
	str_append_cstr(&dump, "eapi.NewShape(");
	str_append_cstr(&dump, body == &body->world->static_body ? "staticBody," : "?,");
	str_append_cstr(&dump, "nil,");
	switch (s->shape_type) {
	case SHAPE_CIRCLE: {
		v = s->shape.circle.offset;
		str_sprintf(&tmp, "{{%i, %i}, %i},", v.x, v.y,
		    s->shape.circle.radius);
		str_append(&dump, &tmp);
		break;
	}
	case SHAPE_RECTANGLE: {
		bb = s->shape.rect;
		str_sprintf(&tmp, "{l=%i,r=%i,b=%i,t=%i},",
		     bb.l, bb.r, bb.b, bb.t);
		str_append(&dump, &tmp);
		break;
	}
	default:
		luaL_error(L, "Unknown shape type: %i.", s->shape_type);
	}
	
	/* Find group by inspecting each group until we find one with the same
	   ID as stored in shape. */
	for (group = body->world->groups; group != NULL;
	    group = group->hh.next) {
		if (group->id == s->group)
			break;
	}
	assert(group != NULL);	/* Should have been there. */
	
	/* Append group name. */
	str_append_cstr(&dump, "\"");
	str_append_cstr(&dump, group->name);
	str_append_cstr(&dump, "\")");

	lua_pushstring(L, dump.data);
	str_destroy(&dump);
	str_destroy(&tmp);
	return 1;
}

/*
 * SelectShape(world, point, groupName=nil) -> shape
 *
 * world	Game world as returned by NewWorld().
 * point	World position vector.
 * group	Ignore all shapes that do not belong to this group.
 *
 * Select the first shape that covers provided point. If none do, return nil.
 */
static int
SelectShape(lua_State *L)
{
	int n;
	uint i, num_shapes;
	vect_i point;
	Shape *s;
	World *world;
	const char *name;
	Group *group;
	BB bb;

	n = lua_gettop(L);
	L_assert(L, n >= 2 && n <= 3, "Invalid number of arguments (%i).", n);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TTABLE);
	
	world = lua_touserdata(L, 1);
	L_assert_objtype(L, world, OBJTYPE_WORLD);
	point = L_getstk_vect_i(L, 2);
	
	/* See if we have to Filter by group name. */
	group = NULL;
	if (!lua_isnoneornil(L, 3)) {
		luaL_checktype(L, 3, LUA_TSTRING);
		name = lua_tostring(L, 3);
		HASH_FIND_STR(world->groups, name, group);
		if (group == NULL)
			return 0;	/* No such group found. */
	}
	
	/* Expand the point a bit to create a bounding box. */
	bb_init(&bb, point.x-1, point.y-1, point.x+1, point.y+1);
	
	/* Look up nearby shapes from quad tree. */
	QTreeObject *intersect[100];
	int too_many = qtree_lookup(&world->shape_tree, &bb, intersect, 100, &num_shapes);
	L_assert(L, !too_many, "Too many shapes in SelectShape().");
	
	/* Go over the lookup shapes. If we find one which really intersects our
	   point (and belong to requested group), return it. */
	for (i = 0; i < num_shapes; i++) {
		s = intersect[i]->ptr;
		assert(s != NULL && s->objtype == OBJTYPE_SHAPE);
		if (group != NULL && s->group != group->id)
			continue;	/* Not in requested group. */
		if (bb_overlap(&bb, &s->go.bb)) {
			lua_pushlightuserdata(L, s);
			return 1;
		}
	}
	return 0;
}


/*
 * __Clear()
 *
 * Destroy sprites, clear out all worlds and schedule them for destruction,
 * unbind all keys.
 */
static int
__Clear(lua_State *L)
{
	extern int *key_bind;
	extern mem_pool mp_camera, mp_body, mp_parallax;
	extern mem_pool mp_group;
	extern World *worlds[WORLDS_MAX];
	extern int drawShapes, drawTileTree, drawShapeTree, outsideView;
	int i;

	L_numarg_check(L, 0);
	glClearColor(0.0, 0.0, 0.0, 0.0);	/* Reset clear color. */
	SDL_ShowCursor(SDL_DISABLE);		/* Hide cursor. */

	/* Fade out all sound channels. */
	audio_fadeout_group(0, 1000);

	/* Disable debug modes. */
	drawShapes = 0;
	drawTileTree = 0;
	drawShapeTree = 0;
	outsideView = 0;

	/* Clear worlds and schedule them for destruction. */
	for (i = 0; i < WORLDS_MAX; i++) {
		if (worlds[i] == NULL)
			continue;
		worlds[i]->killme = 1;
		world_clear(worlds[i]);
	}
	assert(mp_first(&mp_body) == NULL);
	assert(mp_first(&mp_camera) == NULL);
	assert(mp_first(&mp_parallax) == NULL);
	assert(mp_first(&mp_group) == NULL);
	
	/* Destroy textures and sounds that have not been used in a while. */
	texture_free_unused();
	audio_free_unused();

	/* Unbind keys. */
	memset(key_bind, 0, sizeof(uint) * (SDLK_LAST + EXTRA_KEYBIND));
	
	return 0;
}

/*
 * Quit()
 *
 * Terminate program.
 */
static int
Quit(lua_State *L)
{
	L_numarg_check(L, 0);
	exit(EXIT_SUCCESS);
}

/*
 * PlaySound(world, filename, loops=0, volume=1, fadeInTime=0) -> sound
 *
 * world	World as returned by NewWorld(). This is necessary because when
 *		a world is paused, we also must pause all sounds bound to it. If
 *		false is used here, then the sound does not belong to any world.
 * filename	Sound filename (e.g., "script/click.ogg").
 * loops	How many times the sound should be looped. Zero means the sound
 *		will be played only once. -1 will play it forever (until some
 *		other condition stops it).
 * volume	Number in the range [0..1].
 * fadeInTime	The time it takes for sound to go from zero volume to full
 *		volume.
 *
 * Play a sound. Returns a sound handle which can be used to stop the sound or
 * change it's volume, add effects, etc.
 */
static int
PlaySound(lua_State *L)
{
	int n = lua_gettop(L);
	L_assert(L, n >= 2 && n <= 5, "Incorrect number of arguments.");
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L, 2, LUA_TSTRING);
	
	/* World or no world. */
        World *world;
	if (lua_islightuserdata(L, 1)) {
		world = lua_touserdata(L, 1);
		L_assert_objtype(L, world, OBJTYPE_WORLD);
	} else {
		L_assert(L, lua_isboolean(L, 1) && !lua_toboolean(L, 1),
		    "First argument should be either either world or false.");
	    	world = NULL;
	}
	
	int loops = 0;
	if (!lua_isnoneornil(L, 3)) {
		luaL_checktype(L, 3, LUA_TNUMBER);
		loops = lua_tonumber(L, 3);
	}
	L_assert(L, loops >= -1, "Invalid number of loops (%d).", loops);
	
	int volume = MIX_MAX_VOLUME;
	if (!lua_isnoneornil(L, 4)) {
		luaL_checktype(L, 4, LUA_TNUMBER);
		volume = round(lua_tonumber(L, 4) * MIX_MAX_VOLUME);
	}
	L_assert(L, volume >= 0 && volume <= MIX_MAX_VOLUME, "Volume out of "
	    "range.", volume);
	
	int fade_in = 0;
	if (!lua_isnoneornil(L, 5)) {
		luaL_checktype(L, 5, LUA_TNUMBER);
		fade_in = round(lua_tonumber(L, 5) * 1000.0);
	}
	L_assert(L, fade_in >= 0, "Invalid fade-in time.");
	
	/* Start playing. Use world pointer as group number. */
        int channel;
        uint sound_id;
        const char *filename = lua_tostring(L, 2);
	audio_play(filename, (uintptr_t)world, volume, loops, fade_in, &sound_id,
                   &channel);
	
	/* Return sound handle = {soundID=sound_id, channel=ch}. */
	lua_createtable(L, 0, 2);
	lua_pushstring(L, "soundID");
	lua_pushnumber(L, sound_id);
	lua_rawset(L, -3);
	lua_pushstring(L, "channel");
	lua_pushnumber(L, channel);
	lua_rawset(L, -3);
	return 1;
}

/*
 * FadeSound(sound, time)
 *
 * sound	Sound handle as returned by PlaySound().
 *		You may also pass a world here instead of a particual sound. In
 *		this case all sounds belonging to that world will be faded out.
 * time		Fade out time in seconds.
 */
static int
LUA_FadeSound(lua_State *L)
{
	int channel, fade_time;
	uint sound_id;
	World *world;

	L_numarg_check(L, 2);
	luaL_checktype(L, 2, LUA_TNUMBER);
	
	/* Extract fade-out time and convert to milliseconds. */
	fade_time = round(lua_tonumber(L, 2) * 1000.0);
	L_assert(L, fade_time >= 0, "Fade out time must not be negative.");

	switch (lua_type(L, 1)) {
	case LUA_TTABLE:
		/* Extract sound ID and channel. */
		lua_pushstring(L, "soundID");
		lua_rawget(L, 1);
		sound_id = lua_tonumber(L, -1);
		lua_pushstring(L, "channel");
		lua_rawget(L, 1);
		channel = lua_tonumber(L, -1);
		L_assert(L, sound_id > 0, "Invalid sound ID (%i).", sound_id);
		L_assert(L, channel >= 0, "Invalid channel (%i).", channel);
		
                if (fade_time > 0)
                        audio_fadeout(channel, sound_id, fade_time);
                else
                        audio_stop(channel, sound_id);
		return 0;
	case LUA_TLIGHTUSERDATA:
		world = lua_touserdata(L, 1);
		L_assert_objtype(L, world, OBJTYPE_WORLD);
                
                if (fade_time > 0)
                        audio_fadeout_group((uintptr_t)world, fade_time);
                else
                        audio_stop_group((uintptr_t)world);
		return 0;
	default:
		return luaL_error(L, "Invalid argument type (%s). Either sound "
		    "handle or world expected.",
		    lua_typename(L, lua_type(L, 1)));
	}
}

/*
 * BindVolume(sound, source, listener, distMaxVolume, distSilence)
 *
 * sound                Sound handle as returned by PlaySound().
 * source               Object that is producing the sound.
 *                      Accepted types: Body and Camera.
 * listener             Object that "hears" the sound.
 *                      Accepted types: Body and Camera.
 * distMaxVolume        When listener body gets this close to source (or
 *                      closer), then sound is played at max volume.
 * distSilence          When listener body is this far from source (or further),
 *                      then sound volume drops off to zero.
 */
static int
BindVolume(lua_State *L)
{
        L_numarg_check(L, 5);
        luaL_checktype(L, 1, LUA_TTABLE);
        luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
        luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
        luaL_checktype(L, 4, LUA_TNUMBER);
        luaL_checktype(L, 5, LUA_TNUMBER);
	
        /* Extract source body. */
        Body *source;
        int *objtype = lua_touserdata(L, 2);
        L_assert(L, objtype, "Source: NULL object pointer.");
        switch (*objtype) {
        case OBJTYPE_BODY:
                source = (Body *)objtype;
                break;
        case OBJTYPE_CAMERA:
                source = &((Camera *)objtype)->body;
                break;
        default:
                return luaL_error(L, "Invalid source type (%s). Either Body or "
                                  "Camera expected.", L_objtype_name(*objtype));
        }
                                  
        /* Extract listener body. */
        Body *listener;
        objtype = lua_touserdata(L, 3);
        L_assert(L, objtype, "Listener: NULL object pointer.");
        switch (*objtype) {
        case OBJTYPE_BODY:
                listener = (Body *)objtype;
                break;
        case OBJTYPE_CAMERA:
                listener = &((Camera *)objtype)->body;
                break;
        default:
                return luaL_error(L, "Invalid listener type (%s). Either Body or "
                                  "Camera expected.", L_objtype_name(*objtype));
        }
                                  
        /* Extract and verify distances. */
        float dist_maxvol = lua_tonumber(L, 4);
        float dist_silence = lua_tonumber(L, 5);
        L_assert(L, dist_maxvol >= 0.0, "Max volume distance must not be "
                 "negative.");
        L_assert(L, dist_silence > dist_maxvol, "Silence distance must be "
                 "greater than max volume distance");
	
        /* Extract sound ID and channel. */
        lua_pushstring(L, "soundID");
        lua_rawget(L, 1);
        uint sound_id = lua_tonumber(L, -1);
        lua_pushstring(L, "channel");
        lua_rawget(L, 1);
        int channel = lua_tonumber(L, -1);
        L_assert(L, sound_id > 0, "Invalid sound ID (%i).", sound_id);
        L_assert(L, channel >= 0, "Invalid channel (%i).", channel);
        
        audio_bind_volume(channel, sound_id, source, listener, dist_maxvol,
                          dist_silence);
        return 0;
}

/*
 * SetVolume(sound, volume)
 *
 * sound	Sound handle as returned by PlaySound().
 *		You may also pass a world here instead of a particual sound. In
 *		this case all sounds belonging will have their volume changed.
 * volume	Volume must be in range [0..1].
 */
static int
SetVolume(lua_State *L)
{
	int channel, volume;
	uint sound_id;
	World *world;

	L_numarg_check(L, 2);
	luaL_checktype(L, 2, LUA_TNUMBER);
	
	volume = round(lua_tonumber(L, 2) * MIX_MAX_VOLUME);
	L_assert(L, volume >= 0 && volume <= MIX_MAX_VOLUME, "Volume out of "
	    "range.");
	
	switch (lua_type(L, 1)) {
	case LUA_TTABLE:
		/* Extract sound ID and channel. */
		lua_pushstring(L, "soundID");
		lua_rawget(L, 1);
		sound_id = lua_tonumber(L, -1);
		lua_pushstring(L, "channel");
		lua_rawget(L, 1);
		channel = lua_tonumber(L, -1);
		L_assert(L, sound_id > 0, "Invalid sound ID (%i).", sound_id);
		L_assert(L, channel >= 0, "Invalid channel (%i).", channel);
		
		audio_set_volume(channel, sound_id, volume);
		return 0;
	case LUA_TLIGHTUSERDATA:
		world = lua_touserdata(L, 1);
		L_assert_objtype(L, world, OBJTYPE_WORLD);
		audio_set_group_volume((uintptr_t)world, volume);
		return 0;
	default:
 		return luaL_error(L, "Invalid argument type (%s). Either sound "
		    "handle or world expected.",
		    lua_typename(L, lua_type(L, 1)));
	}
}

/*
 * PlayMusic(filename, loops=nil, volume=1, fadeInTime=0, position=0)
 *
 * filename	Music filename (e.g., "script/morning.mp3").
 * loops	How many times the music should be played. `nil` means it
 *		will loop forever (until some other condition stops it).
 * volume	Number in the range [0..1].
 * fadeInTime	The time it takes for sound to go from zero volume to full
 *		volume.
 * position     Jump to `position` seconds from beginning of song.
 *
 * Play music.
 */
static int
LUA_PlayMusic(lua_State *L)
{
        int n = lua_gettop(L);
        L_assert(L, n >= 1 && n <= 5, "Incorrect number of arguments.");
        luaL_checktype(L, 1, LUA_TSTRING);

        int loops = 0;
        if (!lua_isnoneornil(L, 2)) {
                luaL_checktype(L, 2, LUA_TNUMBER);
                loops = lua_tonumber(L, 2);
        }
        L_assert(L, loops >= 0, "Invalid number of loops (%d).", loops);

        int volume = MIX_MAX_VOLUME;
        if (!lua_isnoneornil(L, 3)) {
                luaL_checktype(L, 3, LUA_TNUMBER);
                volume = round(lua_tonumber(L, 3) * MIX_MAX_VOLUME);
        }
        L_assert(L, volume >= 0 && volume <= MIX_MAX_VOLUME, "Volume out of "
                 "range.", volume);

        int fade_in = 0;
        if (!lua_isnoneornil(L, 4)) {
                luaL_checktype(L, 4, LUA_TNUMBER);
                fade_in = round(lua_tonumber(L, 4) * 1000.0);
        }
        L_assert(L, fade_in >= 0, "Invalid fade-in time.");
        
        double pos = 0.0;
        if (!lua_isnoneornil(L, 5)) {
                luaL_checktype(L, 5, LUA_TNUMBER);
                pos = lua_tonumber(L, 5);
        }

        /* Start playing. Use world pointer as group number. */
        const char *filename = lua_tostring(L, 1);
        audio_music_play(filename, volume, loops, fade_in, pos);
        return 0;
}

/*
 * FadeMusic(seconds)
 */
static int
LUA_FadeMusic(lua_State *L)
{
        L_numarg_check(L, 1);
        luaL_checktype(L, 1, LUA_TNUMBER);

        /* Extract fade-out time and convert to milliseconds. */
        int fade_time = round(lua_tonumber(L, 1) * 1000.0);
        L_assert(L, fade_time >= 0, "Fade out time must not be negative.");

        audio_music_fadeout(fade_time);
        return 0;
}

/*
 * SetMusicVolume([0..1])
 */
static int
LUA_SetMusicVolume(lua_State *L)
{
	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TNUMBER);
	
	int volume = round(lua_tonumber(L, 1) * MIX_MAX_VOLUME);
	L_assert(L, volume >= 0 && volume <= MIX_MAX_VOLUME, "Volume out of range.");

	audio_music_set_volume(volume);
        return 0;
}

static int
LUA_PauseMusic(lua_State *L)
{
        L_numarg_check(L, 0);
        audio_music_pause();
}

static int
LUA_ResumeMusic(lua_State *L)
{
        L_numarg_check(L, 0);
        audio_music_resume();
}

static uint32_t seed = 1;

/*
 * RandomSeed(seed)
 *
 * seed		Unsigned integer that seeds the random number generator.
 *
 * Seed random number generator (see Random function).
 */
static int
RandomSeed(lua_State *L)
{
	L_numarg_check(L, 1);
	luaL_checktype(L, 1, LUA_TNUMBER);
	seed = lua_tonumber(L, 1);
	return 0;
}

/* Random number generator from eglibc source. */
static int
rand_eglibc(void)
{
	int result;

	seed *= 1103515245;
	seed += 12345;
	result = (unsigned int) (seed / 65536) % 2048;

	seed *= 1103515245;
	seed += 12345;
	result <<= 10;
	result ^= (unsigned int) (seed / 65536) % 1024;

	seed *= 1103515245;
	seed += 12345;
	result <<= 10;
	result ^= (unsigned int) (seed / 65536) % 1024;

	return result;
}

/*
 * Random() -> number
 *
 * Returns a random number. Use this to have portable randomness (standard
 * library random function implementations differ among platforms).
 */
static int
Random(lua_State *L)
{
	L_numarg_check(L, 0);
	lua_pushnumber(L, rand_eglibc());
	return 1;
}

#ifndef EAPI_MACROS
#define EAPI_MACROS

/* Add function [f] to "eapi" namespace table. */
#define EAPI_ADD_FUNC(L, index, name, f)	\
do {						\
	lua_pushcfunction((L), (f));		\
	lua_setfield((L), (index), (name));	\
} while (0)

/* Add integer to "eapi" namespace table. */
#define EAPI_ADD_INT(L, index, name, c)	\
do {						\
	lua_pushnumber((L), (c));		\
	lua_setfield((L), (index), (name));	\
} while (0)

#endif /* EAPI_ADD */

/*
 * Register engine "API" routines with Lua.
 */
void
eapi_register(lua_State *L, int audio_enabled)
{
	extern int errfunc_index, eapi_index;

	/* Create a namespace "eapi" for all API routines. */
	lua_newtable(L);			/* ... {} */
	lua_setglobal(L, "eapi");		/* ... */

	/* Leave "eapi" table on the stack and remember its index. */
	lua_getglobal(L, "eapi");		/* ... eapi */
	eapi_index = lua_gettop(L);

	/*
	 * Add routines to eapi namespace.
	 */

	/* Constructor functions. */
	EAPI_ADD_FUNC(L, eapi_index, "NewWorld", NewWorld);
	EAPI_ADD_FUNC(L, eapi_index, "NewBody", NewBody);
	EAPI_ADD_FUNC(L, eapi_index, "NewSpriteList", NewSpriteList);
	EAPI_ADD_FUNC(L, eapi_index, "TextureToSpriteList",TextureToSpriteList);
	EAPI_ADD_FUNC(L, eapi_index, "NewTile", NewTile);
	EAPI_ADD_FUNC(L, eapi_index, "NewShape", NewShape);
	EAPI_ADD_FUNC(L, eapi_index, "NewParallax", NewParallax);
	EAPI_ADD_FUNC(L, eapi_index, "NewCamera", NewCamera);
	EAPI_ADD_FUNC(L, eapi_index, "NewPath", NewPath);

	/* Destructor functions. */
	EAPI_ADD_FUNC(L, eapi_index, "__Destroy", __Destroy);
	EAPI_ADD_FUNC(L, eapi_index, "__Clear", __Clear);

	/* Get state. */
	EAPI_ADD_FUNC(L, eapi_index, "GetPos", GetPos);
	EAPI_ADD_FUNC(L, eapi_index, "GetVel", GetVel);
	EAPI_ADD_FUNC(L, eapi_index, "GetDeltaPos", GetDeltaPos);
	EAPI_ADD_FUNC(L, eapi_index, "GetSize", GetSize);
	EAPI_ADD_FUNC(L, eapi_index, "GetBody", GetBody);
	EAPI_ADD_FUNC(L, eapi_index, "GetStaticBody", GetStaticBody);
	EAPI_ADD_FUNC(L, eapi_index, "GetWorld", GetWorld);
	EAPI_ADD_FUNC(L, eapi_index, "__GetStepFunc", __GetStepFunc);
	EAPI_ADD_FUNC(L, eapi_index, "GetFPS", GetFPS);
	EAPI_ADD_FUNC(L, eapi_index, "GetBodyCount", GetBodyCount);
	EAPI_ADD_FUNC(L, eapi_index, "GetState", GetState);
	EAPI_ADD_FUNC(L, eapi_index, "GetTime", GetTime);
	EAPI_ADD_FUNC(L, eapi_index, "GetData", GetData);

	/* Set state. */
	EAPI_ADD_FUNC(L, eapi_index, "SetPos", SetPos);
	EAPI_ADD_FUNC(L, eapi_index, "SetVel", SetVel);
	EAPI_ADD_FUNC(L, eapi_index, "SetVelX", SetVelX);
	EAPI_ADD_FUNC(L, eapi_index, "SetVelY", SetVelY);
	EAPI_ADD_FUNC(L, eapi_index, "SetGravity", SetGravity);
	EAPI_ADD_FUNC(L, eapi_index, "__SetStepFunc", __SetStepFunc);
	EAPI_ADD_FUNC(L, eapi_index, "SetBackgroundColor", SetBackgroundColor);
	EAPI_ADD_FUNC(L, eapi_index, "SetSpriteList", SetSpriteList);
	EAPI_ADD_FUNC(L, eapi_index, "SetAnimPos", SetAnimPos);
	EAPI_ADD_FUNC(L, eapi_index, "SetBoundary", SetBoundary);
	EAPI_ADD_FUNC(L, eapi_index, "SetZoom", SetZoom);
	EAPI_ADD_FUNC(L, eapi_index, "SetState", SetState);
	EAPI_ADD_FUNC(L, eapi_index, "SetFlags", SetFlags);
	EAPI_ADD_FUNC(L, eapi_index, "UnsetFlags", UnsetFlags);
	EAPI_ADD_FUNC(L, eapi_index, "CheckFlags", CheckFlags);
	EAPI_ADD_FUNC(L, eapi_index, "BindToPath", BindToPath);
	
	/* Tile animation. */
	EAPI_ADD_FUNC(L, eapi_index, "SetFrame", SetFrame);
	EAPI_ADD_FUNC(L, eapi_index, "SetFrameLoop", SetFrameLoop);
	EAPI_ADD_FUNC(L, eapi_index, "SetFrameClamp", SetFrameClamp);
	EAPI_ADD_FUNC(L, eapi_index, "SetFrameLast", SetFrameLast);
	EAPI_ADD_FUNC(L, eapi_index, "Animate", Animate);
	EAPI_ADD_FUNC(L, eapi_index, "StopAnimation", StopAnimation);

	/* Get/set object attributes. */
	EAPI_ADD_FUNC(L, eapi_index, "SetAttributes", SetAttributes);
	EAPI_ADD_FUNC(L, eapi_index, "GetAttributes", GetAttributes);
	EAPI_ADD_FUNC(L, eapi_index, "SetRepeatPattern", SetRepeatPattern);

	/* Callbacks and collisions. */
	EAPI_ADD_FUNC(L, eapi_index, "__Collide", __Collide);

	/* Key bindings. */
	EAPI_ADD_FUNC(L, eapi_index, "__BindKey", __BindKey);
	EAPI_ADD_FUNC(L, eapi_index, "GetKeyBindings", GetKeyBindings);
	EAPI_ADD_FUNC(L, eapi_index, "SetKeyBindings", SetKeyBindings);

	/* Body linking. */
	EAPI_ADD_FUNC(L, eapi_index, "Link", Link);
	EAPI_ADD_FUNC(L, eapi_index, "Unlink", Unlink);
	EAPI_ADD_FUNC(L, eapi_index, "GetParent", GetParentFunc);
	EAPI_ADD_FUNC(L, eapi_index, "GetChildren", GetChildren);

	/* Timers. */
	EAPI_ADD_FUNC(L, eapi_index, "__NewTimer", __NewTimer);
	EAPI_ADD_FUNC(L, eapi_index, "RemoveTimer", RemoveTimer);

	/* Random. */
	EAPI_ADD_FUNC(L, eapi_index, "Random", Random);
	EAPI_ADD_FUNC(L, eapi_index, "RandomSeed", RandomSeed);

	/* Misc. */
	EAPI_ADD_FUNC(L, eapi_index, "Pause", Pause);
	EAPI_ADD_FUNC(L, eapi_index, "Resume", Resume);
	EAPI_ADD_FUNC(L, eapi_index, "Quit", Quit);
	EAPI_ADD_FUNC(L, eapi_index, "What", What);
        EAPI_ADD_FUNC(L, eapi_index, "SetGameSpeed", SetGameSpeed);

	/* These are intended for use in editors and while debugging. */
	EAPI_ADD_FUNC(L, eapi_index, "Log", Log);
	EAPI_ADD_FUNC(L, eapi_index, "Dump", Dump);
	EAPI_ADD_FUNC(L, eapi_index, "SelectShape", SelectShape);
	EAPI_ADD_FUNC(L, eapi_index, "NextCamera", NextCamera);
	EAPI_ADD_FUNC(L, eapi_index, "IsValidShape", IsValidShape);
	EAPI_ADD_FUNC(L, eapi_index, "ShowCursor", ShowCursorFunc);
	EAPI_ADD_FUNC(L, eapi_index, "HideCursor", HideCursor);
	EAPI_ADD_FUNC(L, eapi_index, "SwitchFramebuffer", SwitchFramebuffer);
	EAPI_ADD_FUNC(L, eapi_index, "FadeFramebuffer", FadeFramebuffer);
	
	/* Sound. */
	if (audio_enabled) {
		EAPI_ADD_FUNC(L, eapi_index, "PlaySound", PlaySound);
		EAPI_ADD_FUNC(L, eapi_index, "FadeSound", LUA_FadeSound);
		EAPI_ADD_FUNC(L, eapi_index, "SetVolume", SetVolume);
		EAPI_ADD_FUNC(L, eapi_index, "BindVolume", BindVolume);
                
                EAPI_ADD_FUNC(L, eapi_index, "PlayMusic", LUA_PlayMusic);
                EAPI_ADD_FUNC(L, eapi_index, "FadeMusic", LUA_FadeMusic);
                EAPI_ADD_FUNC(L, eapi_index, "SetMusicVolume", LUA_SetMusicVolume);
                EAPI_ADD_FUNC(L, eapi_index, "PauseMusic", LUA_PauseMusic);
                EAPI_ADD_FUNC(L, eapi_index, "ResumeMusic", LUA_ResumeMusic);
	} else {
		EAPI_ADD_FUNC(L, eapi_index, "PlaySound", __Dummy);
                EAPI_ADD_FUNC(L, eapi_index, "FadeSound", __Dummy);
		EAPI_ADD_FUNC(L, eapi_index, "SetVolume", __Dummy);
		EAPI_ADD_FUNC(L, eapi_index, "BindVolume", __Dummy);
                
                EAPI_ADD_FUNC(L, eapi_index, "PlayMusic", __Dummy);
                EAPI_ADD_FUNC(L, eapi_index, "FadeMusic", __Dummy);
                EAPI_ADD_FUNC(L, eapi_index, "SetMusicVolume", __Dummy);
                EAPI_ADD_FUNC(L, eapi_index, "PauseMusic", __Dummy);
                EAPI_ADD_FUNC(L, eapi_index, "ResumeMusic", __Dummy);
	}
	
	/* Animation types. */
	EAPI_ADD_INT(L, eapi_index, "ANIM_NONE", TILE_ANIM_NONE);
	EAPI_ADD_INT(L, eapi_index, "ANIM_LOOP", TILE_ANIM_LOOP);
	EAPI_ADD_INT(L, eapi_index, "ANIM_CLAMP", TILE_ANIM_CLAMP);
	EAPI_ADD_INT(L, eapi_index, "ANIM_REVERSE", TILE_ANIM_REVERSE);
	
	/* Last key index. */
	EAPI_ADD_INT(L, eapi_index, "SDLK_LAST", SDLK_LAST);
	
	/* Load the part of eapi interface that lives in eapi.lua. */
	if ((luaL_loadfile(L, "eapi.lua") ||
	    lua_pcall(L, 0, 0, errfunc_index))) {
		log_err("[Lua] %s", lua_tostring(L, -1));
		abort();
	}
}
