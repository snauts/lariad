--[[
	Part of game engine API that doesn't require any low level access and is
	easier to do in Lua than in C anyway. The actual C API can be found in
	src/eapi.c. Everything here is in the eapi namespace table, just like
	the real API. Names of private functions and variables (those not meant
	to be called/accessed by user scripts) begin with two underscores.
]]--

--[[ The engine provides pointers ("light userdata") to scripts when invoking
	collision handlers, step functions, and timers. To be able to match
	these pointers to data stored client-side (script data), the global
	table eapi.pointerMap defined below can be used for exactly this purpose
	from anywhere in the scripts. ]]--
eapi.pointerMap = {}

local idToObjectMap = {}
local ownerToIdMap = {}
local lastID = 0

--[[
Animation types (added to eapi from the engine during startup):
	eapi.ANIM_NONE
	eapi.ANIM_LOOP
	eapi.ANIM_CLAMP
	eapi.ANIM_REVERSE
--]]

--[[ Generate a new object ID, store object in __idToObjectMap, and return the
	ID. ]]--
local function GenID(obj, owner)
	assert(obj, "GenID() argument evaluates to false.")
	local ID = lastID + 1
	idToObjectMap[ID] = { owner = owner, func = obj }
	if owner then
		if not ownerToIdMap[owner] then ownerToIdMap[owner] = { } end
		ownerToIdMap[owner][ID] = ID
	end
	lastID = ID
	return ID
end

function eapi.Clear()
	-- Clear engine-side state.
	eapi.__Clear()
	
	-- Clear client-side (script) state.
	eapi.pointerMap = {}
	idToObjectMap = {}
	ownerToIdMap = {}
	lastID = 0
	eapi.__doNotSimplyDestroy = {}
end

--[[ Set an object's step function and after-step function. If either function
	is nil, the current step (or after-step) function is unset. ]]--
function eapi.SetStepFunc(objectPtr, stepFunc, afterStepFunc)
	-- Remove previous step function mapping from idToObjectMap.
	local stepFuncID, afterStepFuncID = eapi.__GetStepFunc(objectPtr)
	idToObjectMap[stepFuncID] = nil
	idToObjectMap[afterStepFuncID] = nil
	
	if not stepFunc then
		stepFuncID = 0
	else
		assert(type(stepFunc) == "function",
		    "stepFunc: function expected, got "..type(stepFunc))
		stepFuncID = GenID(stepFunc)
	end
	
	if not afterStepFunc then
		afterStepFuncID = 0
	else
		assert(type(afterStepFunc) == "function",
		    "afterStepFunc: function expected, got "..type(afterStepFunc))
		afterStepFuncID = GenID(afterStepFunc)
	end

	eapi.__SetStepFunc(objectPtr, stepFuncID, afterStepFuncID)
end

--[[ Register a timer function to be called at a specified time.

	obj	World or Body object. Body timers are called only when the
		body is visible or almost visible on screen. World timers
		behave like normal timer functions and will be called when their
		time comes.
	when	How many seconds until timer is called.
	func	Timer function.
]]--
function eapi.AddTimer(obj, when, func)
	when = eapi.GetTime(obj) + when
	return eapi.__NewTimer(obj, when, GenID(func, obj))
end

--[[ Whenever it's necessary to invoke a function if only its ID in the
	__idToObjectMap table is known, the engine calls eapi.__CallFunc() with
	the function ID as argument.

	funcID		ID that maps to a Lua function.
	remove		Remove function from the __idToObjectMap table once
			the function has finished.
]]--
function eapi.__CallFunc(funcID, remove, ...)
	-- Look up function and execute it.
	local func = idToObjectMap[funcID].func
	if remove then
		local owner = idToObjectMap[funcID].owner
		if owner then ownerToIdMap[owner][funcID] = nil end
		idToObjectMap[funcID] = nil
	end
	func(...)
end

function eapi.Destroy(something)
	local idTable = ownerToIdMap[something]
	if idTable then
		for i,_ in pairs(idTable) do
			idToObjectMap[i] = nil
		end
		ownerToIdMap[something] = nil		
	end

	eapi.__Destroy(something)
end

function eapi.BindKey(key, func)
	if not(key == 0) then
		if not func then
			-- Unbind key.
			eapi.__BindKey(key, 0)
			return
		end
		eapi.__BindKey(key, GenID(func))
	end
end

function eapi.__ExecuteKeyBinding(funcID, key, keyDown)
	idToObjectMap[funcID].func(key, keyDown)
end

--[[ Register collision handler.
	world		World object.
	groupNameA/B	Each shape belongs to a group. The name of this group
			is supplied as argument to eapi.NewShape().
			eapi.Collide() accepts as arguments the names of two
			groups, and registers a collision handler to call when
			two shapes belonging to these groups collide.
			groupNameA can be the same as groupNameB. In that case,
			shapes within the same group will collide.
	func		Callback function that will handle collisions between
			pairs of shapes from the two groups.
			Pass in the boolean value 'false' to remove collision
			handler for a particular pair. In this case priority
			must be nil.
	priority	Priority determines the order in which collision
			handlers are called for a particular pair of shapes.
			So lets say we have registered handlers for these two
			pairs:
				"Player" vs "Ground"
				"Player" vs "Exit".
			Now a shape belonging to group "Player" can be
			simultaneously colliding with both a "Ground" shape and
			an "Exit" shape. If priorities are the same for both
			handlers, then the order in which they will be executed
			is undetermined. We can, however, set the priority of
			"Player" vs "Ground" handler to be higher, so that it
			would always be executed first.
]]--
function eapi.Collide(world, groupNameA, groupNameB, func, priority)
	if func == false then
		assert(not priority)
		eapi.__Collide(world, groupNameA, groupNameB, 0, 0)
		return
	end
	assert(type(func) == "function", "Function expected for '"
	    ..groupNameA.."' vs '"..groupNameB.."', got "..type(func)..".")
	if not priority then
		priority = 0
	end
	local id = GenID(func)
	eapi.__Collide(world, groupNameA, groupNameB, id, priority)
end

-- Transition Enums
eapi.CROSSFADE		= 1
eapi.SLIDE_LEFT		= 2
eapi.SLIDE_RIGHT	= 3
eapi.ZOOM_IN		= 4
eapi.ZOOM_OUT		= 5

-- Mouse button IDs.
eapi.MOUSE_BUTTON_LEFT		= eapi.SDLK_LAST + 1
eapi.MOUSE_BUTTON_MIDDLE	= eapi.SDLK_LAST + 2
eapi.MOUSE_BUTTON_RIGHT		= eapi.SDLK_LAST + 3
eapi.MOUSE_BUTTON_WHEELUP	= eapi.SDLK_LAST + 4
eapi.MOUSE_BUTTON_WHEELDOWN	= eapi.SDLK_LAST + 5

eapi.JOY_AXIS0_MINUS		= eapi.SDLK_LAST + 200
eapi.JOY_AXIS0_PLUS		= eapi.SDLK_LAST + 201
eapi.JOY_AXIS1_MINUS		= eapi.SDLK_LAST + 202
eapi.JOY_AXIS1_PLUS		= eapi.SDLK_LAST + 203
eapi.JOY_AXIS2_MINUS		= eapi.SDLK_LAST + 204
eapi.JOY_AXIS2_PLUS		= eapi.SDLK_LAST + 205
eapi.JOY_AXIS3_MINUS		= eapi.SDLK_LAST + 206
eapi.JOY_AXIS3_PLUS		= eapi.SDLK_LAST + 207
eapi.JOY_AXIS4_MINUS		= eapi.SDLK_LAST + 208
eapi.JOY_AXIS4_PLUS		= eapi.SDLK_LAST + 209
eapi.JOY_AXIS5_MINUS		= eapi.SDLK_LAST + 210
eapi.JOY_AXIS5_PLUS		= eapi.SDLK_LAST + 211
eapi.JOY_AXIS6_MINUS		= eapi.SDLK_LAST + 212
eapi.JOY_AXIS6_PLUS		= eapi.SDLK_LAST + 213
eapi.JOY_AXIS7_MINUS		= eapi.SDLK_LAST + 214
eapi.JOY_AXIS7_PLUS		= eapi.SDLK_LAST + 215

eapi.JOY_BUTTON_0		= eapi.SDLK_LAST + 100
eapi.JOY_BUTTON_1		= eapi.SDLK_LAST + 101
eapi.JOY_BUTTON_2		= eapi.SDLK_LAST + 102
eapi.JOY_BUTTON_3		= eapi.SDLK_LAST + 103
eapi.JOY_BUTTON_4		= eapi.SDLK_LAST + 104
eapi.JOY_BUTTON_5		= eapi.SDLK_LAST + 105
eapi.JOY_BUTTON_6		= eapi.SDLK_LAST + 106
eapi.JOY_BUTTON_7		= eapi.SDLK_LAST + 107
eapi.JOY_BUTTON_8		= eapi.SDLK_LAST + 108
eapi.JOY_BUTTON_9		= eapi.SDLK_LAST + 109
eapi.JOY_BUTTON_10		= eapi.SDLK_LAST + 110
eapi.JOY_BUTTON_11		= eapi.SDLK_LAST + 111
eapi.JOY_BUTTON_12		= eapi.SDLK_LAST + 112
eapi.JOY_BUTTON_13		= eapi.SDLK_LAST + 113
eapi.JOY_BUTTON_14		= eapi.SDLK_LAST + 114
eapi.JOY_BUTTON_15		= eapi.SDLK_LAST + 115
eapi.JOY_BUTTON_16		= eapi.SDLK_LAST + 116
eapi.JOY_BUTTON_17		= eapi.SDLK_LAST + 117
eapi.JOY_BUTTON_18		= eapi.SDLK_LAST + 118
eapi.JOY_BUTTON_19		= eapi.SDLK_LAST + 119
eapi.JOY_BUTTON_20		= eapi.SDLK_LAST + 120

-- Key enumeration values.
eapi.KEY_BACKSPACE		= 8
eapi.KEY_TAB		= 9
eapi.KEY_CLEAR		= 12
eapi.KEY_RETURN		= 13
eapi.KEY_PAUSE		= 19
eapi.KEY_ESCAPE		= 27
eapi.KEY_SPACE		= 32
eapi.KEY_EXCLAIM		= 33
eapi.KEY_QUOTEDBL		= 34
eapi.KEY_HASH		= 35
eapi.KEY_DOLLAR		= 36
eapi.KEY_AMPERSAND		= 38
eapi.KEY_QUOTE		= 39
eapi.KEY_LEFTPAREN		= 40
eapi.KEY_RIGHTPAREN		= 41
eapi.KEY_ASTERISK		= 42
eapi.KEY_PLUS		= 43
eapi.KEY_COMMA		= 44
eapi.KEY_MINUS		= 45
eapi.KEY_PERIOD		= 46
eapi.KEY_SLASH		= 47
eapi.KEY_0			= 48
eapi.KEY_1			= 49
eapi.KEY_2			= 50
eapi.KEY_3			= 51
eapi.KEY_4			= 52
eapi.KEY_5			= 53
eapi.KEY_6			= 54
eapi.KEY_7			= 55
eapi.KEY_8			= 56
eapi.KEY_9			= 57
eapi.KEY_COLON		= 58
eapi.KEY_SEMICOLON		= 59
eapi.KEY_LESS		= 60
eapi.KEY_EQUALS		= 61
eapi.KEY_GREATER		= 62
eapi.KEY_QUESTION		= 63
eapi.KEY_AT			= 64
--[[
	   Skip uppercase letters
]]--
eapi.KEY_LEFTBRACKET	= 91
eapi.KEY_BACKSLASH		= 92
eapi.KEY_RIGHTBRACKET	= 93
eapi.KEY_CARET		= 94
eapi.KEY_UNDERSCORE		= 95
eapi.KEY_BACKQUOTE		= 96
eapi.KEY_a			= 97
eapi.KEY_b			= 98
eapi.KEY_c			= 99
eapi.KEY_d			= 100
eapi.KEY_e			= 101
eapi.KEY_f			= 102
eapi.KEY_g			= 103
eapi.KEY_h			= 104
eapi.KEY_i			= 105
eapi.KEY_j			= 106
eapi.KEY_k			= 107
eapi.KEY_l			= 108
eapi.KEY_m			= 109
eapi.KEY_n			= 110
eapi.KEY_o			= 111
eapi.KEY_p			= 112
eapi.KEY_q			= 113
eapi.KEY_r			= 114
eapi.KEY_s			= 115
eapi.KEY_t			= 116
eapi.KEY_u			= 117
eapi.KEY_v			= 118
eapi.KEY_w			= 119
eapi.KEY_x			= 120
eapi.KEY_y			= 121
eapi.KEY_z			= 122
eapi.KEY_DELETE		= 127
--[[ End of ASCII mapped keysyms ]]--

--[[ Numeric keypad ]]--
eapi.KEY_KP0		= 256
eapi.KEY_KP1		= 257
eapi.KEY_KP2		= 258
eapi.KEY_KP3		= 259
eapi.KEY_KP4		= 260
eapi.KEY_KP5		= 261
eapi.KEY_KP6		= 262
eapi.KEY_KP7		= 263
eapi.KEY_KP8		= 264
eapi.KEY_KP9		= 265
eapi.KEY_KP_PERIOD		= 266
eapi.KEY_KP_DIVIDE		= 267
eapi.KEY_KP_MULTIPLY	= 268
eapi.KEY_KP_MINUS		= 269
eapi.KEY_KP_PLUS		= 270
eapi.KEY_KP_ENTER		= 271
eapi.KEY_KP_EQUALS		= 272

--[[ Arrows + Home/End pad ]]--
eapi.KEY_UP			= 273
eapi.KEY_DOWN		= 274
eapi.KEY_RIGHT		= 275
eapi.KEY_LEFT		= 276
eapi.KEY_INSERT		= 277
eapi.KEY_HOME		= 278
eapi.KEY_END		= 279
eapi.KEY_PAGEUP		= 280
eapi.KEY_PAGEDOWN		= 281

--[[ Function keys ]]--
eapi.KEY_F1			= 282
eapi.KEY_F2			= 283
eapi.KEY_F3			= 284
eapi.KEY_F4			= 285
eapi.KEY_F5			= 286
eapi.KEY_F6			= 287
eapi.KEY_F7			= 288
eapi.KEY_F8			= 289
eapi.KEY_F9			= 290
eapi.KEY_F10		= 291
eapi.KEY_F11		= 292
eapi.KEY_F12		= 293
eapi.KEY_F13		= 294
eapi.KEY_F14		= 295
eapi.KEY_F15		= 296

--[[ Key state modifier keys ]]--
eapi.KEY_NUMLOCK		= 300
eapi.KEY_CAPSLOCK		= 301
eapi.KEY_SCROLLOCK		= 302
eapi.KEY_RSHIFT		= 303
eapi.KEY_LSHIFT		= 304
eapi.KEY_RCTRL		= 305
eapi.KEY_LCTRL		= 306
eapi.KEY_RALT		= 307
eapi.KEY_LALT		= 308
eapi.KEY_RMETA		= 309
eapi.KEY_LMETA		= 310
eapi.KEY_LSUPER		= 311		--  Left "Windows" key
eapi.KEY_RSUPER		= 312		--  Right "Windows" key
eapi.KEY_MODE		= 313		--  "Alt Gr" key
eapi.KEY_COMPOSE		= 314		--  Multi-key compose key

eapi.KeyNames = { }
eapi.KeyNames[0]				= " "
eapi.KeyNames[eapi.MOUSE_BUTTON_LEFT]		= "MB_LEFT"
eapi.KeyNames[eapi.MOUSE_BUTTON_MIDDLE]		= "MB_MIDDLE"
eapi.KeyNames[eapi.MOUSE_BUTTON_RIGHT]		= "MB_RIGHT"
eapi.KeyNames[eapi.MOUSE_BUTTON_WHEELUP]	= "MW_UP"
eapi.KeyNames[eapi.MOUSE_BUTTON_WHEELDOWN]	= "WW_DOWN"

eapi.KeyNames[eapi.JOY_AXIS0_MINUS]		= "J_AXIS0-"
eapi.KeyNames[eapi.JOY_AXIS0_PLUS]		= "J_AXIS0+"
eapi.KeyNames[eapi.JOY_AXIS1_MINUS]		= "J_AXIS1-"
eapi.KeyNames[eapi.JOY_AXIS1_PLUS]		= "J_AXIS1+"
eapi.KeyNames[eapi.JOY_AXIS2_MINUS]		= "J_AXIS2-"
eapi.KeyNames[eapi.JOY_AXIS2_PLUS]		= "J_AXIS2+"
eapi.KeyNames[eapi.JOY_AXIS3_MINUS]		= "J_AXIS3-"
eapi.KeyNames[eapi.JOY_AXIS3_PLUS]		= "J_AXIS3+"
eapi.KeyNames[eapi.JOY_AXIS4_MINUS]		= "J_AXIS4-"
eapi.KeyNames[eapi.JOY_AXIS4_PLUS]		= "J_AXIS4+"
eapi.KeyNames[eapi.JOY_AXIS5_MINUS]		= "J_AXIS5-"
eapi.KeyNames[eapi.JOY_AXIS5_PLUS]		= "J_AXIS5+"
eapi.KeyNames[eapi.JOY_AXIS6_MINUS]		= "J_AXIS6-"
eapi.KeyNames[eapi.JOY_AXIS6_PLUS]		= "J_AXIS6+"
eapi.KeyNames[eapi.JOY_AXIS7_MINUS]		= "J_AXIS7-"
eapi.KeyNames[eapi.JOY_AXIS7_PLUS]		= "J_AXIS7+"

eapi.KeyNames[eapi.JOY_BUTTON_0]		= "JB_0"
eapi.KeyNames[eapi.JOY_BUTTON_1]		= "JB_1"
eapi.KeyNames[eapi.JOY_BUTTON_2]		= "JB_2"
eapi.KeyNames[eapi.JOY_BUTTON_3]		= "JB_3"
eapi.KeyNames[eapi.JOY_BUTTON_4]		= "JB_4"
eapi.KeyNames[eapi.JOY_BUTTON_5]		= "JB_5"
eapi.KeyNames[eapi.JOY_BUTTON_6]		= "JB_6"
eapi.KeyNames[eapi.JOY_BUTTON_7]		= "JB_7"
eapi.KeyNames[eapi.JOY_BUTTON_8]		= "JB_8"
eapi.KeyNames[eapi.JOY_BUTTON_9]		= "JB_9"

eapi.KeyNames[eapi.JOY_BUTTON_10]		= "JB_10"
eapi.KeyNames[eapi.JOY_BUTTON_11]		= "JB_11"
eapi.KeyNames[eapi.JOY_BUTTON_12]		= "JB_12"
eapi.KeyNames[eapi.JOY_BUTTON_13]		= "JB_13"
eapi.KeyNames[eapi.JOY_BUTTON_14]		= "JB_14"
eapi.KeyNames[eapi.JOY_BUTTON_15]		= "JB_15"
eapi.KeyNames[eapi.JOY_BUTTON_16]		= "JB_16"
eapi.KeyNames[eapi.JOY_BUTTON_17]		= "JB_17"
eapi.KeyNames[eapi.JOY_BUTTON_18]		= "JB_18"
eapi.KeyNames[eapi.JOY_BUTTON_19]		= "JB_19"
eapi.KeyNames[eapi.JOY_BUTTON_20]		= "JB_20"

eapi.KeyNames[eapi.KEY_BACKSPACE]		= "BACKSPACE"
eapi.KeyNames[eapi.KEY_TAB]			= "TAB"
eapi.KeyNames[eapi.KEY_CLEAR]			= "CLEAR"
eapi.KeyNames[eapi.KEY_RETURN]			= "RETURN"
eapi.KeyNames[eapi.KEY_PAUSE]			= "PAUSE"
eapi.KeyNames[eapi.KEY_ESCAPE]			= "ESCAPE"
eapi.KeyNames[eapi.KEY_SPACE]			= "SPACE"
eapi.KeyNames[eapi.KEY_EXCLAIM]			= "!"
eapi.KeyNames[eapi.KEY_QUOTEDBL]		= "\""
eapi.KeyNames[eapi.KEY_HASH]			= "#"
eapi.KeyNames[eapi.KEY_DOLLAR]			= "$"
eapi.KeyNames[eapi.KEY_AMPERSAND]		= "&"
eapi.KeyNames[eapi.KEY_QUOTE]			= "'"
eapi.KeyNames[eapi.KEY_LEFTPAREN]		= "("
eapi.KeyNames[eapi.KEY_RIGHTPAREN]		= ")"
eapi.KeyNames[eapi.KEY_ASTERISK]		= "*"
eapi.KeyNames[eapi.KEY_PLUS]			= "+"
eapi.KeyNames[eapi.KEY_COMMA]			= ","
eapi.KeyNames[eapi.KEY_MINUS]			= "-"
eapi.KeyNames[eapi.KEY_PERIOD]			= "."
eapi.KeyNames[eapi.KEY_SLASH]			= "/"
eapi.KeyNames[eapi.KEY_0]			= "0"
eapi.KeyNames[eapi.KEY_1]			= "1"
eapi.KeyNames[eapi.KEY_2]			= "2"
eapi.KeyNames[eapi.KEY_3]			= "3"
eapi.KeyNames[eapi.KEY_4]			= "4"
eapi.KeyNames[eapi.KEY_5]			= "5"
eapi.KeyNames[eapi.KEY_6]			= "6"
eapi.KeyNames[eapi.KEY_7]			= "7"
eapi.KeyNames[eapi.KEY_8]			= "8"
eapi.KeyNames[eapi.KEY_9]			= "9"
eapi.KeyNames[eapi.KEY_COLON]			= ":"
eapi.KeyNames[eapi.KEY_SEMICOLON]		= ";"
eapi.KeyNames[eapi.KEY_LESS]			= "<"
eapi.KeyNames[eapi.KEY_EQUALS]			= "="
eapi.KeyNames[eapi.KEY_GREATER]			= ">"
eapi.KeyNames[eapi.KEY_QUESTION]		= "?"
eapi.KeyNames[eapi.KEY_AT]			= "@"

eapi.KeyNames[eapi.KEY_LEFTBRACKET]		= "["
eapi.KeyNames[eapi.KEY_BACKSLASH]		= "\\"
eapi.KeyNames[eapi.KEY_RIGHTBRACKET]		= "]"
eapi.KeyNames[eapi.KEY_CARET]			= "^"
eapi.KeyNames[eapi.KEY_UNDERSCORE]		= "_"
eapi.KeyNames[eapi.KEY_BACKQUOTE]		= "`"

eapi.KeyNames[eapi.KEY_a]			= "A"
eapi.KeyNames[eapi.KEY_b]			= "B"
eapi.KeyNames[eapi.KEY_c]			= "C"
eapi.KeyNames[eapi.KEY_d]			= "D"
eapi.KeyNames[eapi.KEY_e]			= "E"
eapi.KeyNames[eapi.KEY_f]			= "F"
eapi.KeyNames[eapi.KEY_g]			= "G"
eapi.KeyNames[eapi.KEY_h]			= "H"
eapi.KeyNames[eapi.KEY_i]			= "I"
eapi.KeyNames[eapi.KEY_j]			= "J"
eapi.KeyNames[eapi.KEY_k]			= "K"
eapi.KeyNames[eapi.KEY_l]			= "L"
eapi.KeyNames[eapi.KEY_m]			= "M"
eapi.KeyNames[eapi.KEY_n]			= "N"
eapi.KeyNames[eapi.KEY_o]			= "O"
eapi.KeyNames[eapi.KEY_p]			= "P"
eapi.KeyNames[eapi.KEY_q]			= "Q"
eapi.KeyNames[eapi.KEY_r]			= "R"
eapi.KeyNames[eapi.KEY_s]			= "S"
eapi.KeyNames[eapi.KEY_t]			= "T"
eapi.KeyNames[eapi.KEY_u]			= "U"
eapi.KeyNames[eapi.KEY_v]			= "V"
eapi.KeyNames[eapi.KEY_w]			= "W"
eapi.KeyNames[eapi.KEY_x]			= "X"
eapi.KeyNames[eapi.KEY_y]			= "Y"
eapi.KeyNames[eapi.KEY_z]			= "Z"
eapi.KeyNames[eapi.KEY_DELETE]			= "DEL"

eapi.KeyNames[eapi.KEY_KP0]			= "KP0"
eapi.KeyNames[eapi.KEY_KP1]			= "KP1"
eapi.KeyNames[eapi.KEY_KP2]			= "KP2"
eapi.KeyNames[eapi.KEY_KP3]			= "KP3"
eapi.KeyNames[eapi.KEY_KP4]			= "KP4"
eapi.KeyNames[eapi.KEY_KP5]			= "KP5"
eapi.KeyNames[eapi.KEY_KP6]			= "KP6"
eapi.KeyNames[eapi.KEY_KP7]			= "KP7"
eapi.KeyNames[eapi.KEY_KP8]			= "KP8"
eapi.KeyNames[eapi.KEY_KP9]			= "KP9"
eapi.KeyNames[eapi.KEY_KP_PERIOD]		= "KP."
eapi.KeyNames[eapi.KEY_KP_DIVIDE]		= "KP/"
eapi.KeyNames[eapi.KEY_KP_MULTIPLY]		= "KP*"
eapi.KeyNames[eapi.KEY_KP_MINUS]		= "KP-"
eapi.KeyNames[eapi.KEY_KP_PLUS]			= "KP+"
eapi.KeyNames[eapi.KEY_KP_ENTER]		= "KP_ENTER"
eapi.KeyNames[eapi.KEY_KP_EQUALS]		= "KP="

eapi.KeyNames[eapi.KEY_UP]			= "↑"
eapi.KeyNames[eapi.KEY_DOWN]			= "↓"
eapi.KeyNames[eapi.KEY_RIGHT]			= "→"
eapi.KeyNames[eapi.KEY_LEFT]			= "←"

eapi.KeyNames[eapi.KEY_INSERT]			= "INSERT"
eapi.KeyNames[eapi.KEY_HOME]			= "HOME"
eapi.KeyNames[eapi.KEY_END]			= "END"
eapi.KeyNames[eapi.KEY_PAGEUP]			= "PAGE_UP"
eapi.KeyNames[eapi.KEY_PAGEDOWN]		= "PAGE_DOWN"

eapi.KeyNames[eapi.KEY_F1]			= "F1"
eapi.KeyNames[eapi.KEY_F2]			= "F2"
eapi.KeyNames[eapi.KEY_F3]			= "F3"
eapi.KeyNames[eapi.KEY_F4]			= "F4"
eapi.KeyNames[eapi.KEY_F5]			= "F5"
eapi.KeyNames[eapi.KEY_F6]			= "F6"
eapi.KeyNames[eapi.KEY_F7]			= "F7"
eapi.KeyNames[eapi.KEY_F8]			= "F8"
eapi.KeyNames[eapi.KEY_F9]			= "F9"
eapi.KeyNames[eapi.KEY_F10]			= "F10"
eapi.KeyNames[eapi.KEY_F11]			= "F11"
eapi.KeyNames[eapi.KEY_F12]			= "F12"
eapi.KeyNames[eapi.KEY_F13]			= "F13"
eapi.KeyNames[eapi.KEY_F14]			= "F14"
eapi.KeyNames[eapi.KEY_F15]			= "F15"

eapi.KeyNames[eapi.KEY_NUMLOCK]			= "NUMLOCK"
eapi.KeyNames[eapi.KEY_CAPSLOCK]		= "CAPSLOCK"
eapi.KeyNames[eapi.KEY_SCROLLOCK]		= "SCROLLOCK"
eapi.KeyNames[eapi.KEY_RSHIFT]			= "RSHIFT"
eapi.KeyNames[eapi.KEY_LSHIFT]			= "LSHIFT"
eapi.KeyNames[eapi.KEY_RCTRL]			= "RCTRL"
eapi.KeyNames[eapi.KEY_LCTRL]			= "LCTRL"
eapi.KeyNames[eapi.KEY_RALT]			= "RALT"
eapi.KeyNames[eapi.KEY_LALT]			= "LALT"
eapi.KeyNames[eapi.KEY_RMETA]			= "RMETA"
eapi.KeyNames[eapi.KEY_LMETA]			= "LMETA"
eapi.KeyNames[eapi.KEY_RSUPER]			= "RWIN"
eapi.KeyNames[eapi.KEY_LSUPER]			= "LWIN"
eapi.KeyNames[eapi.KEY_MODE]			= "MODE"
eapi.KeyNames[eapi.KEY_COMPOSE]			= "COMPOSE"
