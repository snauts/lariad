#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <assert.h>
#include <errno.h>
#include <math.h>
#include <stdint.h>
#include <unistd.h>	/* Needed for chdir(), works under MinGW. */

#include <SDL.h>
#include <SDL_image.h>
#include <SDL_opengl.h>

#include "audio.h"
#include "config.h"
#include "draw.h"
#include "game2d.h"
#include "log.h"
#include "lua_util.h"
#include "mem.h"
#include "misc.h"
#include "path.h"
#include "physics.h"
#include "world.h"
#include "str.h"

void	eapi_register(lua_State *L, int audio_enabled);	/* Defined in eapi.c */

/* The following functions are defined at the bottom of this file. */
static void	setup_memory();
static void	cleanup();
static void	draw(Camera *cam);
static void	process_events();
static void	exec_key_binding(lua_State *L, SDLKey key, uint8_t state);
static void	read_cfg_file();
static void	parse_cmd_opt(int argc, char *argv[]);
static void	game_window();

World	*worlds[WORLDS_MAX];	/* Pointers to all worlds are stored here. */
Camera	*cameras[CAMERAS_MAX];	/* Pointers to all cameras are stored here. */

/* Misc state. */
int	drawShapes, drawTileTree, drawShapeTree, outsideView;

/* Memory pools. */
mem_pool mp_world, mp_camera, mp_parallax;
mem_pool mp_shape, mp_listvect, mp_path;
mem_pool mp_texture, mp_sprite, mp_tile;
mem_pool mp_sound;
mem_pool mp_body;
mem_pool mp_treenode, mp_treeobjptr;
mem_pool mp_group;

/* Static globals. */
static lua_State	*L;			/* Lua state. */
static int		lua_stack_size;		/* For debugging. */
static uint32_t		fps_time;		/* Last FPS update time. */

/*
 * Game time is the time spent actually advancing (stepping) worlds. It can be
 * less than actual time (time since program start) due to lag or someone
 * suspending engine process.
 */
uint64_t game_time;

uint	*key_bind;		/* Lua function IDs bound to keys. */
float	frames_per_second;

/* Various Lua stack locations. */
int	eapi_index;		/* "eapi" namespace table stack location. */
int	errfunc_index;		/* Error handler stack location. */
int	callfunc_index;		/* eapi.__CallFunc. */
static int keyfunc_index;	/* eapi.__ExecuteKeyBinding.*/

/*
 * This function is pushed onto Lua stack, and its index is passed into
 * lua_pcall() as the errfunc parameter. This means that whenever there's an
 * error, Lua will call this function.
 *
 * The point of this is so we get to print the call stack (traceback). Without
 * such an error handler, when lua_pcall() returns, the interesting part of the
 * stack has already been unwound and is no longer accessible.
 */
static int
error_handler(lua_State *L)
{
	int rc;

	rc = luaL_dostring(L, "io.stderr:write(debug.traceback(\"error_handler():\",3) .. '\\n')");
	lua_pushstring(L, lua_tostring(L, 1));
	return 1;
}

void bind_framebuffer(void);
void draw_framebuffer(void);
void cleanup_framebuffer(void);

static SDL_Joystick *joystick[MAX_JOYSTICKS];

int main(int argc, char *argv[])
{
	uint32_t now, before, delta_time, game_delta_time, remainder;
	int steps_per_frame, fps_count, world_i, cam_i, arg_i, sound_works, i;
	const SDL_version *sdl_version;
	World *world;

	log_open(NULL);		/* Log output goes to stderr. */
	
	/* Init strings. */
        str_init(&config.name);
	str_init(&config.version);
	str_init(&config.location);
	
	/* Start Lua. */
	L = luaL_newstate();
	luaL_openlibs(L);
	lua_stack_size = lua_gettop(L);

	/* Push error handler on stack. */
	lua_pushcfunction(L, error_handler);
	errfunc_index = lua_gettop(L);

	/* Find user application directory in command line options (-L). */
	for (arg_i = 1; arg_i < argc; arg_i++) {
		if (strcmp(argv[arg_i], "-L") != 0)
			continue;
		if (arg_i + 1 == argc)
			break;
		str_assign_cstr(&config.location, argv[arg_i+1]);
	}
	/* Change working dir to what was specified. */
	if (str_length(&config.location) > 0 &&
	    chdir(config.location.data) != 0) {
		log_err("Could not change working directory to %s: %s",
		    config.location.data, strerror(errno));
		abort();
	}
	/* Read configuration file, then parse command line options because they
	   take precedence (they will overwrite values read from config). */
	read_cfg_file();
	parse_cmd_opt(argc, argv);

	/* Allocate memory for pools & set atexit() which will free them. */
	setup_memory();
	atexit(cleanup);

	/* Print game name and version. */
        cfg_get_str("name", &config.name);
	cfg_get_str("version", &config.version);
	log_msg("%s version: %s", config.name.data, config.version.data);

	/* Print SDL version. */
	sdl_version = SDL_Linked_Version();
	log_msg("SDL version: %u.%u.%u", sdl_version->major, sdl_version->minor,
	    sdl_version->patch);
	
	/* Initialize SDL. */
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK) == -1) {
		log_err("SDL_Init() failed: %s", SDL_GetError());
		exit(EXIT_FAILURE);
	}
	
	/* Initialize sound & create game window. */
	sound_works = audio_init();
	game_window();

	/* Allocate key binding array. We add SDLK_LAST to mouse button
	   enumerations so their bindings can be stored in the same array.*/
	key_bind = mem_alloc(sizeof(uint) * (SDLK_LAST + EXTRA_KEYBIND),
	    "Key bindings");
	memset(key_bind, 0, sizeof(uint) * (SDLK_LAST + EXTRA_KEYBIND));

	for(i = 0; i < MAX_JOYSTICKS; i++) {
		joystick[i] = NULL;
	}
	for(i = 0; i < MIN2(SDL_NumJoysticks(), MAX_JOYSTICKS); i++) {
		printf("Using %s\n", SDL_JoystickName(i));
		SDL_JoystickEventState(SDL_ENABLE);
		joystick[i] = SDL_JoystickOpen(i);
	}
	

	if (!check_extension("GL_EXT_framebuffer_object"))
		log_warn("GL_EXT_framebuffer_object not present.");
	if (!check_extension("GL_ARB_imaging"))
		log_warn("GL_ARB_imaging not present.");
	if (!check_extension("GL_ARB_vertex_buffer_object"))
		log_warn("GL_ARB_vertex_buffer_object not present.");
	if (GET_CFG("printExtensions", cfg_get_bool, 0))
		log_msg("OpenGL extensions: %s", glGetString(GL_EXTENSIONS));

	glDisable(GL_ALPHA_TEST);
	glDisable(GL_BLEND);
	glDisable(GL_DITHER);
	glDisable(GL_FOG);
	glDisable(GL_LIGHTING);
	glDisable(GL_NORMALIZE);
	glDisable(GL_DEPTH_TEST);
	
	glEnable(GL_TEXTURE_2D);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	/*glEnable(GL_MULTISAMPLE);*/
	/*glEnable(GL_CULL_FACE);	 Discard back-facing polygons. */

	/* No fancy alignment: we want our bytes packed tight. */
	glPixelStorei(GL_PACK_ALIGNMENT, 1);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

	/* Register "API" functions with Lua. */
	eapi_register(L, sound_works);
	
	/* Leave eapi.__CallFunc and eapi.__ExecKeyBinding functions on stack
	   since we use them often. */
	lua_getfield(L, eapi_index, "__CallFunc");
	callfunc_index = lua_gettop(L);
	lua_getfield(L, eapi_index, "__ExecuteKeyBinding");
	keyfunc_index = lua_gettop(L);
	
	/* Execute user script. */
	if ((luaL_loadfile(L, "script/first.lua") ||
	    lua_pcall(L, 0, 0, errfunc_index))) {
		log_err("[Lua] %s", lua_tostring(L, -1));
		abort();
	}

	if (cameras[0] == NULL) {
		log_err("No camera!");
		abort();
	}

	/* Modelview stack. */
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();	/* Keep identity matrix at the bottom. */

	/* Main loop. */
	game_time = 0;		/* Game time starts at zero. */
	remainder = 0;		/* Used in game time calculations. */
	before = fps_time = SDL_GetTicks();
	fps_count = 0;
	for (;;) {
		now = SDL_GetTicks();	/* Current real time. */
		
		/* Compute how much time has passed since last time. Watch out
		   for time wrap-around. */
		delta_time = (now >= before) ? now - before :
		    (uint32_t)-1 - before + now;
		before = now;
		
		/*
		 * If there was some huge lag, don't make worlds catch
		 * up. Instead, assume last frame took 50ms.
		 */
		if (delta_time > 50)
			delta_time = 50;
		
		/* Adjust game delta time depending on game speed. */
		if (config.gameSpeed != 0) {
			if (config.gameSpeed >= 0) {
				game_delta_time = delta_time * config.gameSpeed;
			} else {
				game_delta_time = (delta_time + remainder)/(-config.gameSpeed);
				remainder = (delta_time + remainder)%(-config.gameSpeed);
			}
		} else {
			/* Game delta equals real delta time. */
			game_delta_time = delta_time;
		}
		game_time += game_delta_time;	/* Advance game time. */
		
		/* Calculate frames per second. */
		fps_count++;
		if (now - fps_time >= config.FPSUpdateInterval) {
			frames_per_second = fps_count*1000.0 / (now - fps_time);
			fps_time = now;
			fps_count = 0;
		}
		
		/* Handle user input. */
		process_events();
                
                /* Adjust audio volume for channels that are bound to bodies. */
                audio_adjust_volume();
		
		/* Step worlds. */
		for (world_i = 0; world_i < WORLDS_MAX; world_i++) {
			if ((world = worlds[world_i]) == NULL || world->killme)
				continue;
			
			/* Bring world up to present game time. */
			steps_per_frame = 0;
			while (game_time >= world->next_step_time) {
				world->next_step_time += world->step_ms;
				if (world->paused)
					continue;

				/* Step world -- execute body step
				   functions, timers, collision handlers. */
				world_step(world, L, steps_per_frame++ == 0);
				world->virgin = 0;
				
				/* Handle user input. To be more responsive, we
				   do this here between steps too. */
				process_events();
				
				if (world->killme)
					break;	/* No need to keep going. */
			}
		}
		
		/*
		 * Deal with worlds that have either been destroyed or created
		 * in the loop above. Must do this here, before rendering, so
		 * that we don't get a "stale" frame.
		 */
		for (world_i = 0; world_i < WORLDS_MAX; world_i++) {
			if ((world = worlds[world_i]) == NULL)
				continue;

			/* Remove dying worlds, and perform the initial
			   step on recently created worlds. */
			if (world->killme) {
				world_free(world);
				worlds[world_i] = NULL;
			} else if (world->virgin) {
				/* We must give scripts control over what the
				   contents of the world look like before
				   drawing it. Otherwise we get such artifacts
				   as camera centered on origin even though it
				   should be tracking a player character. */
				world_step(world, L, 1);
				world->virgin = 0;
			}
		}

		/*
		 * Draw what each camera sees.
		 *
		 * Calling glClear(GL_COLOR_BUFFER_BIT) to clear frame buffer
		 * before anything is rendered isn't necessary, but may be done
		 * here if desired.
		 */
		bind_framebuffer();
		for (cam_i = 0; cam_i < CAMERAS_MAX; cam_i++) {
			if (cameras[cam_i] != NULL)
				draw(cameras[cam_i]);
		}
		draw_framebuffer();
		/*
		 * These may be executed here, but don't seem to do much.
		 * glFlush();
		 * glFinish();
		 */
		SDL_GL_SwapBuffers();
	}
	/* NOTREACHED */
}

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
	
	/* Draw visible tiles. */
	glBegin(GL_QUADS);
	for (i = 0; i < num_tiles; i++) {
		tile = visible_tiles[i]->ptr;
		assert(tile->objtype == OBJTYPE_TILE);
		
		/* The tile should not have been added to tree if it has no
		   sprites. */
		assert(tile->sprite_list != NULL &&
		    tile->sprite_list->num_frames > 0);
		
		draw_tile(cam, tile);
	}
	glEnd();
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

static void
draw(Camera *cam)
{
	Matrix m;
	Body *bp;
	BB visible_area;
	vect_i visible_size, visible_halfsize;
	World *world;

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

static void joystick_movement(uint8_t state, int axis, int *dirs) {
    if (dirs[axis]) {
	int sym = (dirs[axis] + 1) / 2;
	sym += SDLK_LAST + 200 + axis * 2;
	exec_key_binding(L, sym, state);
    }
}

static void joy_up(int axis, int *dirs) {
    joystick_movement(SDL_KEYUP, axis, dirs);
}

static void joy_down(int axis, int *dirs) {
    joystick_movement(SDL_KEYDOWN, axis, dirs);
}

/*
 * Process input/window events.
 */
static void
process_events()
{
	uint8_t state;
	SDLKey sym;
	SDL_Event ev;
	static int axis_dir[MAX_AXIS];
	
	while (SDL_PollEvent(&ev) != 0) {
		switch (ev.type) {
		case SDL_QUIT:
			exit(EXIT_SUCCESS);
		case SDL_KEYDOWN:
			sym = ev.key.keysym.sym;
			state = SDL_KEYDOWN;
#ifdef __APPLE__
                        /* Handle `Command + Q` and `Command + H` events on Mac OS X. */
                        SDLMod mod = ev.key.keysym.mod;
                        if (mod == KMOD_LMETA || mod == KMOD_RMETA) {
                                if (sym == SDLK_q)
                                        exit(EXIT_SUCCESS);
                                if (sym == SDLK_h)
                                        SDL_WM_IconifyWindow();
                        }
#endif
			break;
		case SDL_KEYUP:
			sym = ev.key.keysym.sym;
			state = SDL_KEYUP;
			break;
		case SDL_JOYAXISMOTION:  /* Handle Joystick Motion */
			if (ev.jaxis.axis >= MAX_AXIS) {
				static int done = 0;
				if (done) continue; 
				printf("joy axis %i moved\n", ev.jaxis.axis);
				printf("please report to developers\n");
				done = 1;
				continue;
			}
			joy_up(ev.jaxis.axis, axis_dir);
			if (abs(ev.jaxis.value) > 3200) {
				int dir = ev.jaxis.value > 0 ? 1 : -1;
				axis_dir[ev.jaxis.axis] = dir;
				joy_down(ev.jaxis.axis, axis_dir);
			}
			else {
				axis_dir[ev.jaxis.axis] = 0;			
			}
			continue;
		case SDL_JOYBUTTONDOWN:
			sym = SDLK_LAST + ev.jbutton.button + 100;
			state = SDL_KEYDOWN;
			break;
		case SDL_JOYBUTTONUP:
			sym = SDLK_LAST + ev.jbutton.button + 100;
			state = SDL_KEYUP;
			break;
		case SDL_MOUSEBUTTONDOWN:
			sym = SDLK_LAST + ev.button.button;
			state = SDL_KEYDOWN;
			break;
		case SDL_MOUSEBUTTONUP:
			sym = SDLK_LAST + ev.button.button;
			state = SDL_KEYUP;
			break;
		default:
			continue;
		}
	
		/* Execute function bound to this key (if any). */
		exec_key_binding(L, sym, state);
	}
}

static void
exec_key_binding(lua_State *L, SDLKey key, uint8_t state)
{
	uint func_id;

	func_id = key_bind[key];
	if (func_id == 0)
		return;
	
	lua_pushvalue(L, keyfunc_index);	/* ... func? */
	assert(lua_isfunction(L, -1));		/* ... func */

	lua_pushinteger(L, func_id);		/* ... func func_id */
	lua_pushinteger(L, key);		/* ... func func_id keyNum */
	lua_pushboolean(L, state == SDL_KEYDOWN); /* ... func func_id keyNum keyState */
	if (lua_pcall(L, 3, 0, errfunc_index)) {
		log_err("[Lua] %s", lua_tostring(L, -1));
		abort();
	}
}

/*
 * Parse command line options.
 */
static void
parse_cmd_opt(int argc, char *argv[])
{
	int opt;
	extern int opterr;
	extern char *optarg;

	opterr = 0;	/* Disable getopt_bsd() error reporting. */
	while ((opt = getopt_bsd(argc, argv, "fwL:")) != -1) {
		switch (opt) {
		case 'f':
			config.fullscreen = 1;
			break;
		case 'w':
			config.fullscreen = 0;
			break;
		case 'L':
			str_assign_cstr(&config.location, optarg);
			break;
		default:
			log_msg("Usage: %s [-f] [-w] [-L app_location]", argv[0]);
			log_msg("\t-w\tRun in windowed mode.");
			log_msg("\t-f\tRun in fullscreen mode.");
			log_msg("\t-L\tPath to application directory.");
			exit(EXIT_FAILURE);
		}
	}
}

/*
 * Read configuration file.
 */
static void
read_cfg_file()
{
	float color[4];
	
	cfg_read("config.lua");

	/*
	 * Cache some configuration.
	 */
	config.FPSUpdateInterval
	    = GET_CFG("FPSUpdateInterval", cfg_get_int, 500);
	config.fullscreen = cfg_get_bool("fullscreen");
	config.force_native = cfg_get_bool("forceNative");
	config.gameSpeed = cfg_get_int("gameSpeed");
	if (cfg_has_field("defaultShapeColor")) {
	    cfg_get_color("defaultShapeColor", color);
	    config.defaultShapeColor = color_floatv_to_uint32(color);
	}
	else {
	    config.defaultShapeColor = 0xff66cc00;
	}
	config.screen_width = GET_CFG("screenWidth", cfg_get_int, 800);
	config.screen_height = GET_CFG("screenHeight", cfg_get_int, 480);
	config.window_width = cfg_get_int("windowWidth");
	config.window_height = cfg_get_int("windowHeight");
	config.screen_bpp = cfg_get_int("screenBPP");
}

static void calculate_screen_dimensions(void) {
	float screen_aspect = (float) config.screen_width 
			    / (float) config.screen_height;
	float window_aspect = (float) config.window_width 
			    / (float) config.window_height;

	if (screen_aspect > window_aspect) {
		float offset = 0.5 * (1.0 - window_aspect / screen_aspect);
		config.w_b = offset;
		config.w_t = 1.0 - offset;
		config.w_l = 0.0;
		config.w_r = 1.0;
	}
	else {
		float offset = 0.5 * (1.0 - screen_aspect / window_aspect);
		config.w_b = 0.0;
		config.w_t = 1.0;
		config.w_l = offset;
		config.w_r = 1.0 - offset;
	}
}

static void
game_window()
{
	int value;
	SDL_Surface	*scr;
	Uint32		video_flags;
	const SDL_VideoInfo *vinfo;
	int double_buf = 1;
	int swap_control = 1;

	/* Set OpenGL attributes. */
	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, double_buf);
	SDL_GL_SetAttribute(SDL_GL_SWAP_CONTROL, swap_control);
	/*SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
	SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 4);*/

	/* Get desktop width & height. */
	vinfo = SDL_GetVideoInfo();
	assert(vinfo != NULL);
	if (config.fullscreen && config.force_native) {
		/* use native video mode while in fullscreen */
		config.window_width = vinfo->current_w;
		config.window_height = vinfo->current_h;
	}
	calculate_screen_dimensions();

	/* Create game window. */
	SDL_WM_SetCaption(config.name.data, config.name.data);
	video_flags = (SDL_OPENGL | SDL_DOUBLEBUF | SDL_HWSURFACE);
	if (config.fullscreen)
		video_flags |= SDL_FULLSCREEN;
	scr = SDL_SetVideoMode(config.window_width, config.window_height,
	    config.screen_bpp, video_flags);
	if (scr == NULL) {
		log_err("SDL_SetVideoMode() failed: %s", SDL_GetError());
		abort();
	}
	config.screen_bpp = scr->format->BitsPerPixel;

	SDL_GL_GetAttribute(SDL_GL_DOUBLEBUFFER, &value);
	if (value != double_buf)
		log_warn("Double buffer attribute: %i", value);
	SDL_GL_GetAttribute(SDL_GL_SWAP_CONTROL, &value);
	if (value != swap_control)
		log_warn("Swap control attribute: %i", value);

	log_msg("OpenGL platform: %s, %s, %s", glGetString(GL_RENDERER),
	    glGetString(GL_VENDOR), glGetString(GL_VERSION));
	log_msg("Bits per pixel: %u", config.screen_bpp);
	
	/* In fullscreen mode move mouse cursor to bottom right of screen. Why?
	   Because due to buggy video drivers or whatever, on Linux sometimes
	   cursor is visible in fullscreen mode even if hidden. It is somewhat
	   less annoying if the cursor does not sit right in the center of the
	   screen. */
#ifdef __linux__
	if (config.fullscreen)
		SDL_WarpMouse(config.screen_width-1, config.screen_height-1);
#endif
	SDL_ShowCursor(SDL_DISABLE);
}

void
setup_memory()
{
	mem_pool_init(&mp_world, sizeof(World), WORLDS_MAX, "World pool");
	mem_pool_init(&mp_camera, sizeof(Camera), CAMERAS_MAX, "Camera pool");
	mem_pool_init(&mp_parallax, sizeof(Parallax),
	    WORLDS_MAX * WORLD_PX_PLANES_MAX, "Parallax pool");
	
	mem_pool_init(&mp_shape, sizeof(Shape), 4000, "Shape pool");
	mem_pool_init(&mp_listvect, sizeof(vect_f_list), 100, "List vector pool");
	mem_pool_init(&mp_path, sizeof(Path), 20, "Path pool");
	
	mem_pool_init(&mp_texture, sizeof(Texture), 100, "Texture pool");
	mem_pool_init(&mp_sprite, sizeof(SpriteList), 1000, "SpriteList pool");
	mem_pool_init(&mp_tile, sizeof(Tile), TILES_MAX, "Tile pool");
	mem_pool_init(&mp_body, sizeof(Body), 10000, "Body pool");
	mem_pool_init(&mp_treenode, sizeof(QTreeNode), 20000, "Quad tree node "
	    "pool");
	mem_pool_init(&mp_treeobjptr, sizeof(QTreeObjectPtr), 50000,
	    "Quad tree object pointer pool");
	mem_pool_init(&mp_group, sizeof(Group), WORLD_HANDLERS_MAX,
	    "Shape collision group pool");
}

/*
 * Perform cleanup.
 */
static void
cleanup()
{
	int i;
	for(i = 0; i < MAX_JOYSTICKS; i++) {
		if (joystick[i]) SDL_JoystickClose(joystick[i]);
	}
	audio_close();	/* Close audio if it was opened. */
	SDL_Quit();	/* Finally, kill SDL. */
}
