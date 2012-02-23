-- Program configuration.

local eapi = eapi or { }

Cfg = {
        name = "Lariad",
	version = "0.4",

	-- Display.
	fullscreen	= false,
	windowWidth	= 800,
	windowHeight	= 480,
	screenBPP	= 0,		-- 0 = current bits per pixel.
	
	-- Sound.
	channels	= 16,		-- Number of mixing channels.
	frequency	= 22050,	-- Use 44100 for 44.1KHz (CD audio).
	chunksize	= 512,		-- Less is slower but more accurate.
	stereo		= true,		-- Mono or stereo output.

	-- Editor.
	loadEditor		= true,
	defaultShapeColor	= {r=0.0, g=0.8, b=0.4},
	selectedShapeColor	= {r=0.9, g=0,   b=0.5},
	invalidShapeColor	= {r=0.8, g=0.4, b=0.1},

	-- Debug things.
	forceNative	= true,
	screenWidth	= 800,
	screenHeight	= 480,
	printExtensions = false,	-- Print the OpenGL extension string.
	FPSUpdateInterval = 500,	-- FPS update interval in milliseconds.
	gameSpeed = 0,			-- Negative values slow the game down,
					-- positive values speed it up.

	keyLeft  = { eapi.KEY_LEFT, eapi.JOY_BUTTON_15, eapi.JOY_AXIS0_MINUS },
	keyRight = { eapi.KEY_RIGHT, eapi.JOY_BUTTON_13, eapi.JOY_AXIS0_PLUS },
	keyUp    = { eapi.KEY_UP, eapi.JOY_BUTTON_12, eapi.JOY_AXIS1_MINUS },
	keyDown  = { eapi.KEY_DOWN, eapi.JOY_BUTTON_14, eapi.JOY_AXIS1_PLUS },
	keyJump  = { eapi.KEY_z, eapi.JOY_BUTTON_1 },
	keyShoot = { eapi.KEY_x, eapi.JOY_BUTTON_2 },
	keyESC	 = { eapi.KEY_ESCAPE, eapi.JOY_BUTTON_3 },

	texts	 = "script/Texts.en.lua",
	startLives = 3,
}

-- Make sure the configuration is sane.
assert(Cfg.screenWidth >= 200 and Cfg.screenHeight >= 120)

assert(Cfg.channels > 0 and Cfg.channels <= 16)
assert(Cfg.frequency == 22050 or Cfg.frequency == 44100)
assert(Cfg.stereo == true or Cfg.stereo == false)
assert(Cfg.chunksize >= 256 and Cfg.chunksize <= 8192)

assert(Cfg.FPSUpdateInterval > 0);
assert(Cfg.gameSpeed >= -10 and Cfg.gameSpeed <= 10)

return Cfg
