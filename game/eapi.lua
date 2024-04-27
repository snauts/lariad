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
	local callback = { owner = owner, func = obj, ID = ID }
	idToObjectMap[ID] = callback
	if owner then
		if not ownerToIdMap[owner] then ownerToIdMap[owner] = { } end
		ownerToIdMap[owner][ID] = ID
	end
	lastID = ID
	return callback
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
		stepFuncID = GenID(stepFunc).ID
	end
	
	if not afterStepFunc then
		afterStepFuncID = 0
	else
		assert(type(afterStepFunc) == "function",
		    "afterStepFunc: function expected, got "..type(afterStepFunc))
		afterStepFuncID = GenID(afterStepFunc).ID
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
	local callback = GenID(func, obj)
	callback.timer = eapi.__NewTimer(obj, when, callback.ID)
	return callback
end

function eapi.DelTimer(callback)
	eapi.RemoveTimer(callback.timer)
	idToObjectMap[callback.ID] = nil
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
		eapi.__BindKey(key, GenID(func).ID)
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
	local id = GenID(func).ID
	eapi.__Collide(world, groupNameA, groupNameB, id, priority)
end

-- Transition Enums
eapi.CROSSFADE		= 1
eapi.SLIDE_LEFT		= 2
eapi.SLIDE_RIGHT	= 3
eapi.ZOOM_IN		= 4
eapi.ZOOM_OUT		= 5

-- Mouse button IDs.
eapi.SDLK_LAST = 512 -- SDL_NUM_SCANCODES
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
eapi.KEY_BACKSPACE		= 42
eapi.KEY_TAB		= 43
eapi.KEY_RETURN		= 40
eapi.KEY_ESCAPE		= 41
eapi.KEY_SPACE		= 44
eapi.KEY_1			= 30
eapi.KEY_2			= 31
eapi.KEY_3			= 32
eapi.KEY_4			= 33
eapi.KEY_5			= 34
eapi.KEY_6			= 35
eapi.KEY_7			= 36
eapi.KEY_8			= 37
eapi.KEY_9			= 38
eapi.KEY_0			= 39

eapi.KEY_a			= 4
eapi.KEY_b			= 5
eapi.KEY_c			= 6
eapi.KEY_d			= 7
eapi.KEY_e			= 8
eapi.KEY_f			= 9
eapi.KEY_g			= 10
eapi.KEY_h			= 11
eapi.KEY_i			= 12
eapi.KEY_j			= 13
eapi.KEY_k			= 14
eapi.KEY_l			= 15
eapi.KEY_m			= 16
eapi.KEY_n			= 17
eapi.KEY_o			= 18
eapi.KEY_p			= 19
eapi.KEY_q			= 20
eapi.KEY_r			= 21
eapi.KEY_s			= 22
eapi.KEY_t			= 23
eapi.KEY_u			= 24
eapi.KEY_v			= 25
eapi.KEY_w			= 26
eapi.KEY_x			= 27
eapi.KEY_y			= 28
eapi.KEY_z			= 29

--[[ End of ASCII mapped keysyms ]]--

eapi.KEY_KP_ENTER              = 88
eapi.KEY_DELETE                = 76

--[[ Arrows + Home/End pad ]]--
eapi.KEY_UP			= 82
eapi.KEY_DOWN		= 81
eapi.KEY_RIGHT		= 79
eapi.KEY_LEFT		= 80

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
eapi.KeyNames[eapi.KEY_RETURN]			= "RETURN"
eapi.KeyNames[eapi.KEY_ESCAPE]			= "ESCAPE"
eapi.KeyNames[eapi.KEY_SPACE]			= "SPACE"
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

eapi.KeyNames[eapi.KEY_KP_ENTER]	= "KP ENTER"
eapi.KeyNames[eapi.KEY_DELETE]		= "DELETE"

eapi.KeyNames[eapi.KEY_UP]			= "↑"
eapi.KeyNames[eapi.KEY_DOWN]			= "↓"
eapi.KeyNames[eapi.KEY_RIGHT]			= "→"
eapi.KeyNames[eapi.KEY_LEFT]			= "←"

