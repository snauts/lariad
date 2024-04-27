#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <assert.h>
#include <errno.h>
#include <math.h>
#include <stdint.h>

#include <SDL.h>
#include <SDL_image.h>
#include <SDL_opengl.h>
#include <emscripten.h>

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
#include "framebuffer.h"

static SDL_Window *win;

extern Config config;
extern void (*glBindFramebuffer)(GLenum target, GLuint framebuffer);

void	eapi_register(lua_State *L, int audio_enabled);	/* Defined in eapi.c */

/* The following functions are defined at the bottom of this file. */
static void	setup_memory();
static void	cleanup();
static void	process_events();
static void	exec_key_binding(lua_State *L, SDL_Keysym key, int state);
static void	read_cfg_file();
static SDL_Window *game_window();
static void calculate_screen_dimensions(void);

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

/* Lua function IDs bound to keys. */
uint key_bind[SDL_NUM_SCANCODES + EXTRA_KEYBIND];

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

static SDL_Joystick *joystick[MAX_JOYSTICKS];

static uint32_t now, before, delta_time, game_delta_time, remaindr;
static int steps_per_frame, fps_count, world_i, sound_works, i;
static World *world;

static void
game_loop() {
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
			game_delta_time = (delta_time + remaindr)/(-config.gameSpeed);
			remaindr = (delta_time + remaindr)%(-config.gameSpeed);
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
	*/
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	for (int cam_i = 0; cam_i < CAMERAS_MAX; cam_i++) {
		if (cameras[cam_i] != NULL)
			draw(cameras[cam_i]);
	}

	// draw_framebuffer_effects();

	/*
	* These may be executed here, but don't seem to do much.
	* glFlush();
	* glFinish();
	*/
	SDL_GL_SwapWindow(win);
}

EMSCRIPTEN_KEEPALIVE
void startup() {
	emscripten_set_main_loop(game_loop, 0, 1);
}

int main()
{
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

	/* Read configuration file. */
	read_cfg_file();

	/* Allocate memory for pools & set atexit() which will free them. */
	setup_memory();
	atexit(cleanup);

	/* Print game name and version. */
	cfg_get_str("name", &config.name);
	cfg_get_str("version", &config.version);
	log_msg("%s version: %s", config.name.data, config.version.data);

	/* Print SDL version. */
	SDL_version sdl_version;
	SDL_GetVersion(&sdl_version);
	log_msg("SDL version: %u.%u.%u", sdl_version.major, sdl_version.minor, sdl_version.patch);

	/* Initialize SDL. */
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK) == -1) {
		log_err("SDL_Init() failed: %s", SDL_GetError());
		exit(EXIT_FAILURE);
	}

	/* Initialize sound & create game window. */
	sound_works = audio_init();
	win = game_window();

	config.screen_width = config.window_width;
	config.screen_height = config.window_height;
	calculate_screen_dimensions();

	for(i = 0; i < MAX_JOYSTICKS; i++) {
		joystick[i] = NULL;
	}
	for(i = 0; i < MIN2(SDL_NumJoysticks(), MAX_JOYSTICKS); i++) {
		SDL_JoystickEventState(SDL_ENABLE);
		joystick[i] = SDL_JoystickOpen(i);
		printf("Using %s\n", SDL_JoystickName(joystick[i]));
	}

	log_msg("OpenGL extensions: %s", glGetString(GL_EXTENSIONS));

	glDisable(GL_ALPHA_TEST);
	glDisable(GL_BLEND);
	glDisable(GL_DITHER);
	glDisable(GL_FOG);
	glDisable(GL_LIGHTING);
	glDisable(GL_NORMALIZE);
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_SCISSOR_TEST);

	glEnable(GL_TEXTURE_2D);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnableClientState(GL_VERTEX_ARRAY); // Enable vertex arrays
	glEnableClientState(GL_COLOR_ARRAY); // Enable color arrays
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);

	/* No fancy alignment: we want our bytes packed tight. */
	glPixelStorei(GL_PACK_ALIGNMENT, 1);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

	init_framebuffers();

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

	/* Main loop init. */
	game_time = 0;		/* Game time starts at zero. */
	remaindr = 0;		/* Used in game time calculations. */
	before = fps_time = SDL_GetTicks();
	fps_count = 0;

	/*
	* Synchronize from IndexedDB to Emscripten MEMFS ("saavgaam" file location).
	* Then callback into C to start the game.
	*/
	EM_ASM({
		FS.mkdir("/savedata");
		FS.mount(IDBFS, {}, "/savedata");
		FS.syncfs(true, function (err) {
			if (err) {
			console.error("Error mounting filesystem:", err);
			} else {
			console.log("Filesystem mounted and synchronized!");
			Module['_startup']();
			}
		});
	});
	return 0;
}

static void joystick_movement(int state, int axis, int *dirs) {
    if (dirs[axis]) {
	int sym = (dirs[axis] + 1) / 2;
	sym += SDL_NUM_SCANCODES + 200 + axis * 2;
	SDL_Keysym key;
	key.scancode = sym;
	exec_key_binding(L, key, state);
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
	int state;
	SDL_Keysym key;
	SDL_Event ev;
	static int axis_dir[MAX_AXIS];

	while (SDL_PollEvent(&ev) != 0) {
		switch (ev.type) {
		case SDL_QUIT:
			exit(EXIT_SUCCESS);
		case SDL_KEYDOWN:
			key = ev.key.keysym;
			state = SDL_KEYDOWN;
			break;
		case SDL_KEYUP:
			key = ev.key.keysym;
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
			key.scancode = SDL_NUM_SCANCODES + ev.jbutton.button + 100;
			state = SDL_KEYDOWN;
			break;
		case SDL_JOYBUTTONUP:
			key.scancode = SDL_NUM_SCANCODES + ev.jbutton.button + 100;
			state = SDL_KEYUP;
			break;
		case SDL_MOUSEBUTTONDOWN:
			key.scancode = SDL_NUM_SCANCODES + ev.button.button;
			state = SDL_KEYDOWN;
			break;
		case SDL_MOUSEBUTTONUP:
			key.scancode = SDL_NUM_SCANCODES + ev.button.button;
			state = SDL_KEYUP;
			break;
		default:
			continue;
		}

		/* Execute function bound to this key (if any). */
		exec_key_binding(L, key, state);
	}
}

static void
exec_key_binding(lua_State *L, SDL_Keysym key, int state)
{
	uint func_id;

	func_id = key_bind[key.scancode];
	if (func_id == 0)
		return;

	lua_pushvalue(L, keyfunc_index);	/* ... func? */
	assert(lua_isfunction(L, -1));		/* ... func */

	lua_pushinteger(L, func_id);		/* ... func func_id */
	lua_pushinteger(L, key.scancode);		/* ... func func_id keyNum */
	lua_pushboolean(L, state == SDL_KEYDOWN);	/* ... func func_id keyNum keyState */
	if (lua_pcall(L, 3, 0, errfunc_index)) {
		log_err("[Lua] %s", lua_tostring(L, -1));
		abort();
	}
}

/*
 * Read configuration file.
 */
static void
read_cfg_file()
{
	cfg_read("config.lua");

	/*
	 * Cache some configuration.
	 */
	config.FPSUpdateInterval
	    = GET_CFG("FPSUpdateInterval", cfg_get_int, 500);
	config.force_native = cfg_get_bool("forceNative");
	config.gameSpeed = cfg_get_int("gameSpeed");
	if (cfg_has_field("defaultShapeColor")) {
	    cfg_get_color("defaultShapeColor", config.defaultShapeColor);
	}
	else {
	    config.defaultShapeColor[0] = 1.0;
		config.defaultShapeColor[1] = 0.4;
		config.defaultShapeColor[2] = 0.8;
		config.defaultShapeColor[3] = 0.0;
	}
	config.screen_width = GET_CFG("screenWidth", cfg_get_int, 800);
	config.screen_height = GET_CFG("screenHeight", cfg_get_int, 480);
	config.window_width = cfg_get_int("windowWidth");
	config.window_height = cfg_get_int("windowHeight");
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

static SDL_Window *
game_window()
{
	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

	SDL_DisplayMode display;
	SDL_GetDesktopDisplayMode(0, &display);

	/* Create window. */
	uint32_t flags = SDL_WINDOW_OPENGL;
	SDL_Window *win = SDL_CreateWindow("Lariad", SDL_WINDOWPOS_CENTERED,
		SDL_WINDOWPOS_CENTERED,
		config.window_width,
		config.window_height, flags);
	if (win == NULL)
			fatal_error("SDL_CreateWindow() failed: %s.", SDL_GetError());
	SDL_ShowWindow(win);
	SDL_DisableScreenSaver();
	SDL_ShowCursor(SDL_DISABLE);

	/* Create OpenGL context. */
	SDL_GLContext context = SDL_GL_CreateContext(win);
	if (context == NULL) {
			fatal_error("Could not create OpenGL context: %s",
						SDL_GetError());
	}
	SDL_GL_MakeCurrent(win, context);

	int r, g, b, a;
	SDL_GL_GetAttribute(SDL_GL_RED_SIZE, &r);
	SDL_GL_GetAttribute(SDL_GL_GREEN_SIZE, &g);
	SDL_GL_GetAttribute(SDL_GL_BLUE_SIZE, &b);
	SDL_GL_GetAttribute(SDL_GL_ALPHA_SIZE, &a);
	log_msg("OpenGL platform: %s, %s, %s", glGetString(GL_RENDERER),
			glGetString(GL_VENDOR), glGetString(GL_VERSION));
	log_msg("Framebuffer component sizes (RGBA): %d %d %d %d", r, g, b, a);
	if (a == 0)
			log_warn("Missing framebuffer alpha.");

	return win;
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
