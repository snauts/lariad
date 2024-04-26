-- Program configuration.

local eapi = eapi or { }

Cfg = {
        name = "Lariad",
	version = "1.x.x",

	-- Display.
	fullscreen	= false,
	windowWidth	= 800,
	windowHeight	= 480,
	screenBPP	= 0,		-- 0 = current bits per pixel.
	
	-- Sound.
	channels	= 16,		-- Number of mixing channels.
	frequency	= 22050,	-- Use 44100 for 44.1KHz (CD audio).
	chunksize	= 2048,		-- Less is slower but more accurate.
	stereo		= true,		-- Mono or stereo output.

	-- Debug things.
	forceNative	= true,
	gameSpeed	= 0,		-- Negative values slow the game down,
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

return Cfg
