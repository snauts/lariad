
-- User supplied editing routines.
exports = {}

local camera = {}
camera.ptr = nil

-- Editor state.
local state = {
	world=nil,		-- World that we're attached to.
	staticBody=nil,		-- Static body from our world.
	points={},		-- Points accumulated thus far.

	tmpShape=nil,		-- A temporary editor shape.
	selectedShape=nil,	-- Presently selected editor shape.
	origColor=nil,		-- Original color of selected shape.

	grabShape=nil,		-- Grabbed shape that's being moved.
	grabPosition=nil,	-- Last grabbed shape (mouse) position.

	filename=nil,		-- Where to save created stuff.
	selectedFuncName=nil,	-- Name of selected user function.

	area=nil,		-- Bounding box for current "editor" shape that
				-- contains all objects created by user.
	ctrlKeyPressed=false,	-- Keep track of control key state.
}

-- Store user created objects here.
local userObjects = {
	name=nil,		-- Name of function that created the objects.
	args=nil,		-- Arguments that are passed into user function.
	offset={x=0,y=0},	-- Offset (needed when moving objects around).

	shapes={},
	tiles={},
	bodies={},
}

-- Complete list of user created objects. Each "Editor" shape owns a list of
-- user objects (see userObjects above). The scene table below is a mapping from
-- "Editor" shapes to userObjects that establishes this relationship.
local scene = {}

local function CamControl(key, keyDown)
	if key == eapi.KEY_w then
		camera.moveUp = keyDown
	elseif key == eapi.KEY_a then
		camera.moveLeft = keyDown
	elseif key == eapi.KEY_s then
		camera.moveDown = keyDown
	elseif key == eapi.KEY_d then
		camera.moveRight = keyDown
	end
end

local function MoveCamera(camera, pos, zoom)
	if camera.moveLeft then
		pos.x = pos.x - 5/zoom
	end
	if camera.moveRight then
		pos.x = pos.x + 5/zoom
	end
	if camera.moveUp then
		pos.y = pos.y + 5/zoom
	end
	if camera.moveDown then
		pos.y = pos.y - 5/zoom
	end
	eapi.SetPos(camera.ptr, pos)
end

--[[ Destroy user objects owned by the argument shape. Note that before
	destroying something we check if it actually exists within the engine.
]]--
local function DestroyEditorShape(shape)
	local userObj = scene[shape]
	
	-- Destroy shapes.
	for _, shape in ipairs(userObj.shapes) do
		if eapi.What(shape) == "Shape" then
                        print(eapi.Dump(shape, "    "))
			eapi.Destroy(shape)
		end
	end
	
	-- Destroy tiles.
	for _, tile in ipairs(userObj.tiles) do
		if eapi.What(tile) == "Tile" then
			eapi.Destroy(tile)
		end
	end
	
	-- Destroy bodies.
	for _, body in ipairs(userObj.bodies) do
		if eapi.What(body) == "Body" then
			eapi.Destroy(body)
		end
	end
	
	-- Remove "Editor" shape from our scene and destroy it.
	scene[shape] = nil
	eapi.Destroy(shape)
end

--[[ Move editor shape, along with the user objects it owns, by delta vector
	distance. ]]--
local function MoveEditorShape(editorShape, delta)
	local userObj = scene[editorShape]
	local movedBodies = {}
	
	-- Move tiles.
	for _, tile in ipairs(userObj.tiles) do
		if eapi.What(tile) == "Tile" then
			local body = eapi.GetBody(tile)
			
			if body == state.staticBody then
				-- Tile belongs to static body. Don't move the
				-- body; adjust tile's relative position.
				local pos = eapi.GetPos(tile)
				eapi.SetPos(tile, vector.Add(pos, delta))
			elseif not movedBodies[body] then
				-- The body has not been moved yet; do it.
				local pos = eapi.GetPos(body)
				eapi.SetPos(body, vector.Add(pos, delta))
				movedBodies[body] = true
			end
		end
	end
	
	-- Move shapes.
	for _, shape in ipairs(userObj.shapes) do
		if eapi.What(shape) == "Shape" then
			local body = eapi.GetBody(shape)
			
			if body == state.staticBody then
				-- Shape belongs to static body. Don't move the
				-- body; adjust shape's relative position.
				eapi.SetPos(shape, delta)
			elseif not movedBodies[body] then
				-- The body has not been moved yet; do it.
				local pos = eapi.GetPos(body)
				eapi.SetPos(body, vector.Add(pos, delta))
				movedBodies[body] = true
			end
		end
	end
	
	-- Move bodies.
	for _, body in ipairs(userObj.bodies) do
		if eapi.What(body) == "Body" then
			if not movedBodies[body] then
				-- The body has not been moved yet; do it.
				local pos = eapi.GetPos(body)
				eapi.SetPos(body, vector.Add(pos, delta))
				movedBodies[body] = true
			end
		end
	end
	
	-- Move "Editor" shape itself.
	eapi.SetPos(editorShape, delta)

	-- Adjust offset in userObj (used when saving file).
	userObj.offset = vector.Add(userObj.offset, delta)
end

--[[ Left mouse button adds a new point to the point list. ]]--
local function LMB(button, pressed)
	if not pressed then
		return
	end
	local pos = camera.data.mousePos
	
	if state.grabShape then
		state.grabShape = nil
		return
	end
	
	if #state.points > 0 then
		-- Ignore the point if it's the same as last one.
		local lastPoint = state.points[#state.points]
		if pos.x == lastPoint.x and pos.y == lastPoint.y then
			return
		end
	end
	
	table.insert(state.points, pos)
end

--[[ Right mouse button either cancels the shape presently being created, or
	grabs selected shape for moving. ]]--
local function RMB(button, pressed)
	if not pressed then
		return
	end
	
	-- Clear accumulated points.
	state.points = {}
	
	-- Ungrab shape.
	if state.grabShape then
		state.grabShape = nil
		return
	end
	
	-- Destroy the shape we're in the process of creating.
	if state.tmpShape then
		eapi.Destroy(state.tmpShape)
		if state.tmpShape == state.selectedShape then
			state.selectedShape = nil
		end
		state.tmpShape = nil
		return
	end
	
	-- Select shape for moving.
	if not state.grabShape and state.selectedShape then
		state.grabShape = state.selectedShape
		state.grabPosition = camera.data.mousePos
		return
	end
end

--[[ Middle mouse button deletes selected shape. ]]--
local function MMB(key, pressed)
	if not pressed then
		return
	end
	if not state.selectedShape or state.selectedShape == state.tmpShape then
		return
	end
	
	if state.selectedShape == state.grabShape then
		state.grabShape = nil
	end
	
	print(eapi.Dump(state.selectedShape))
	DestroyEditorShape(state.selectedShape)
	state.selectedShape = nil
end

local function Scroll(key, keyDown)
	if not keyDown then
		return
	end
	local zoom = camera.data.zoom
	if key == eapi.MOUSE_BUTTON_WHEELUP then
		eapi.SetZoom(camera.ptr, zoom + zoom * 0.1)
	else
		eapi.SetZoom(camera.ptr, zoom - zoom * 0.1)
	end
end

local function ChooseFN(name)
	return function ()
		       eapi.Log("[Editor] Selected: "..name)
		       state.selectedFuncName = name 
		       return "exit"
	       end
end

local function EditorMenu(key, keyDown)
	local i = 1
	local items = { }
	if not keyDown then return end

	for name, value in pairs(exports) do
		if not value.hide then
			items[i] = { active = true,
				     disableKill = true,
				     fn = ChooseFN(name),
				     text = name }
			items[i].select = (name == state.selectedFuncName)
			i = i + 1
		end
	end
	table.sort(items, function(a, b) return (a.text < b.text) end)
	util.ShowMenu(nil, true, nil, items)
	state.points = {}
end

local function FormatPoint(pos, offset)
	return "{x="..pos.x+offset.x..",y="..pos.y+offset.y.."}"
end

local function IsBox(box)
	return type(box) == "table" and box.l and box.r and box.t and box.b
end

local function FormatBox(box, offset)
	return "{l="..box.l+offset.x..",r="..box.r+offset.x..
	       ",b="..box.b+offset.y..",t="..box.t+offset.y.."}"
end

local function SaveFile(key, keyDown)
	if not keyDown then
		return
	end
	
	eapi.Log("[Editor] Saving '"..state.filename.."'")
	
	local f = io.open(state.filename, "w")
	if not f then
		eapi.Log("[Editor] Could not open '"..state.filename.."' fpr writing.")
		return
	end
	for editorShape, userObj in pairs(scene) do
		local name = userObj.name
		local args = userObj.args
		local offset = userObj.offset
		local argStr = ""
		local comma = ""
		local last = 0
		for i, v in pairs(args) do
			local str = nil
			for j = last + 1, i - 1, 1 do
				argStr = argStr..",nil"
			end
			if vector.Check(v) then
				str = FormatPoint(v, offset)
			elseif IsBox(v) then
				str = FormatBox(v, offset)
			else
				str = game.FormatValue(v)
			end
			argStr = argStr..comma..str
			comma = ","
			last = i
		end
		f:write("exports."..name..".func("..argStr..")\n")
	end
	f:close()

	-- to get nicer version control diffs, ugly but simple 
	os.execute("sort " .. state.filename .. " > tmp-file-for-sort.lua")
	os.execute("mv tmp-file-for-sort.lua " .. state.filename)
end

local function DisplayMousePos(camera)
	-- Create mouse position string.
	local mousePos = camera.data.mousePos
	local mousePosText = mousePos.x .. ", " .. mousePos.y

	-- Destroy previous mouse position text tiles.
	if camera.mousePosTiles then
		util.Map(eapi.Destroy, camera.mousePosTiles)
		camera.mousePosTiles = nil
	end

	-- Create mouse position text tiles.
	camera.mousePosTiles =
		util.DialogBox({ mousePosText }, camera, { x = 16, y = 32 })
end

-- Original eapi.New* functions will be saved in these variables.
local NewShape = nil
local NewTile = nil
local NewBody = nil

local function MyNewShape(body, pos, rect, ...)
	local bodyPos = eapi.GetPos(body)
	local absRect = {l=rect.l,r=rect.r,b=rect.b,t=rect.t}
	pos = pos or {x=0,y=0}
	
	-- Translate shape rectangle to absolute (world) coordinates.
	absRect.l = absRect.l + bodyPos.x + pos.x
	absRect.r = absRect.r + bodyPos.x + pos.x
	absRect.b = absRect.b + bodyPos.y + pos.y
	absRect.t = absRect.t + bodyPos.y + pos.y
	
	-- Union with current user area.
	if not state.area then
		state.area = absRect
	else
		state.area.l = math.min(state.area.l, absRect.l)
		state.area.r = math.max(state.area.r, absRect.r)
		state.area.b = math.min(state.area.b, absRect.b)
		state.area.t = math.max(state.area.t, absRect.t)
	end
	
	-- Call the real eapi.NewShape function; store created shape.
	local shape = NewShape(body, pos, rect, ...)
	table.insert(userObjects.shapes, shape)
	return shape
end

local function MyNewTile(body, pos, size, spriteList, ...)
	local bodyPos = eapi.GetPos(body)
	local absRect = {l=0,r=0,b=0,t=0}
	pos = pos or {x=0,y=0}

	if size then
		absRect.r = size.x
		absRect.t = size.y
	else
		local spriteSize = eapi.GetSize(spriteList)
		absRect.r = spriteSize.x
		absRect.t = spriteSize.y
	end

	-- Translate tile rectangle to absolute (world) coordinates.
	absRect.l = absRect.l + bodyPos.x + pos.x
	absRect.r = absRect.r + bodyPos.x + pos.x
	absRect.b = absRect.b + bodyPos.y + pos.y
	absRect.t = absRect.t + bodyPos.y + pos.y

	-- Union with current user area.
	if not state.area then
		state.area = absRect
	else
		state.area.l = math.min(state.area.l, absRect.l)
		state.area.r = math.max(state.area.r, absRect.r)
		state.area.b = math.min(state.area.b, absRect.b)
		state.area.t = math.max(state.area.t, absRect.t)
	end

	-- Call the real eapi.NewShape function; store created tile.
	local tile = NewTile(body, pos, size, spriteList, ...)
	table.insert(userObjects.tiles, tile)
	return tile
end

local function MyNewBody(world, pos)
	-- Union with current user area.
	if not state.area then
		state.area = {l=pos.x,r=pos.x,b=pos.y,t=pos.y}
	else	
		state.area.l = math.min(state.area.l, pos.x)
		state.area.r = math.max(state.area.r, pos.x)
		state.area.b = math.min(state.area.b, pos.y)
		state.area.t = math.max(state.area.t, pos.y)
	end

	local body = NewBody(world, pos)
	table.insert(userObjects.bodies, body)
	return body
end

local function UserProxy(funcName, ...)
	-- Save eapi.New* functions.
	NewShape = eapi.NewShape
	NewTile = eapi.NewTile
	NewBody = eapi.NewBody

	-- Replace them with our own versions.
	eapi.NewShape = MyNewShape
	eapi.NewTile = MyNewTile
	eapi.NewBody = MyNewBody

	-- Execute user function.
	exports[funcName].userFunc(...)

	-- Save function name and arguments.
	userObjects.name = funcName	-- Save function name.
	userObjects.args = {...}

	-- Restore original eapi.New* functions.
	eapi.NewShape = NewShape
	eapi.NewTile = NewTile
	eapi.NewBody = NewBody

	if state.area then
		-- Make the "Editor" shape a 32x32 square in the center of
		-- created shapes/tiles.
		local center = {x=util.Round((state.area.r + state.area.l)/2),
				y=util.Round((state.area.b + state.area.t)/2)}
		state.area.l = center.x - 16
		state.area.r = center.x + 16
		state.area.b = center.y - 16
		state.area.t = center.y + 16

		local editorShape = eapi.NewShape(state.staticBody, nil, state.area, "Editor")
		eapi.SetAttributes(editorShape, {color={r=0.5,g=0,b=0.5}})

		-- New "Editor" shape is now responsible for the created
		-- user objects.
		scene[editorShape] = userObjects
		state.area = nil		-- Reset user area.
	else
		eapi.Log("WARNING: User function did not create anything.")
	end

	-- Clear out user objects table.
	userObjects = {
		name=nil,
		args=nil,
		offset={x=0,y=0},

		shapes={},
		tiles={},
		bodies={}
	}
end

local function CameraStep(worldPtr, camPtr)
	camera.data = eapi.GetData(camera.ptr)

	DisplayMousePos(camera)
	MoveCamera(camera, camera.data.pos, camera.data.zoom)

	-- Destroy the shape we're in the process of creating (the shape is
	-- destroyed and created each step).
	if state.tmpShape then
		eapi.Destroy(state.tmpShape)
		state.tmpShape = nil
	end
	
	-- Position shape that's being moved.
	if state.grabShape then
		local pos = camera.data.mousePos
		local delta = vector.Sub(pos, state.grabPosition)
		if delta.x ~= 0 or delta.y ~= 0 then
			MoveEditorShape(state.grabShape, delta)
			state.grabPosition = pos
		end
		return
	end
	
	if state.selectedShape and eapi.What(state.selectedShape) ~= "Shape" then
		eapi.Log("WARNING: Selected shape became "..eapi.What(state.selectedShape)..".")
		state.selectedShape = nil
	end

	local shapeUnderMouse = eapi.SelectShape(state.world, camera.data.mousePos, "Editor")
	if shapeUnderMouse then
		if state.selectedShape and shapeUnderMouse ~= state.selectedShape then
			eapi.SetAttributes(state.selectedShape, {color=state.origColor})
			state.selectedShape = nil
		end
		
		if not state.selectedShape then
			-- Remember presently selected shape's original color,
			-- and then set a new one to highlight it.
			state.origColor = eapi.GetAttributes(shapeUnderMouse).color
			eapi.SetAttributes(shapeUnderMouse, {color=Cfg.selectedShapeColor})
		end
	elseif state.selectedShape then
		eapi.SetAttributes(state.selectedShape, {color=state.origColor})
	end
	state.selectedShape = shapeUnderMouse

	if #state.points == 0 or not state.selectedFuncName then
		-- No user function selected, or no points created so far.
		return
	end

	-- Get how many points user function requires.
	local needPoints = exports[state.selectedFuncName].points
	
	-- Draw a bounding box shape for functions that need 2 points.
	if #state.points == 1 and needPoints == 2 then
		local mp = camera.data.mousePos
		local bb = {
			l=math.min(state.points[1].x, mp.x)-1,
			r=math.max(state.points[1].x, mp.x)+1,
			b=math.min(state.points[1].y, mp.y)-1,
			t=math.max(state.points[1].y, mp.y)+1
		}
		state.tmpShape = eapi.NewShape(state.staticBody, nil, bb, "Editor")
		eapi.SetAttributes(state.tmpShape, {color={r=0.5,g=0,b=0.5}})
	end
	
	-- See if we have enough points to call user function with them.
	if #state.points >= needPoints then
		if needPoints == 1 then
			-- For one point, give that point to user function.
			UserProxy(state.selectedFuncName, state.points[1])
		elseif needPoints == 2 then
			-- For two points, supply a bounding box to user func.
			local rect = {
				l=math.min(state.points[1].x, state.points[2].x),
				r=math.max(state.points[1].x, state.points[2].x),
				b=math.min(state.points[1].y, state.points[2].y),
				t=math.max(state.points[1].y, state.points[2].y)
			}
			UserProxy(state.selectedFuncName, rect)
		else
			-- For more points, give them all to user function.
			UserProxy(state.selectedFuncName, unpack(state.points))
		end

		state.points = {}	-- Clear points.
	end
end

local function CycleCameras(key, keyDown)
	if not keyDown then
		return
	end
	
	camera.ptr = eapi.NextCamera(camera.ptr)
	eapi.SetBoundary(camera.ptr, nil)
	eapi.SetStepFunc(camera.ptr, CameraStep)
end

local function PlacePlayer()
	eapi.SetPos(mainPC.body, camera.data.mousePos)
end

local function Show()
	if not Cfg.loadEditor then
		eapi.Log("[Editor] To be able to edit, enable loadEditor option in config.lua")
		return
	end

	if next(exports, nil) == nil then
		eapi.Log("[Editor] User function table is empty. You will not be able to create anything.")
	end

	eapi.SetState("drawShapes", true)
	eapi.ShowCursor()

	-- Key bindings.
	eapi.BindKey(eapi.KEY_w, CamControl)
	eapi.BindKey(eapi.KEY_a, CamControl)
	eapi.BindKey(eapi.KEY_s, CamControl)
	eapi.BindKey(eapi.KEY_d, CamControl)
	eapi.BindKey(eapi.KEY_p, PlacePlayer)
	eapi.BindKey(eapi.KEY_F2, CycleCameras)
	eapi.BindKey(eapi.KEY_TAB, EditorMenu)
	eapi.BindKey(eapi.KEY_LCTRL, function(_,kd) state.ctrlKeyPressed=kd end)
	eapi.BindKey(eapi.KEY_RCTRL, function(_,kd) state.ctrlKeyPressed=kd end)
	eapi.BindKey(eapi.KEY_q, SaveFile)
	eapi.BindKey(eapi.MOUSE_BUTTON_LEFT, LMB)
	eapi.BindKey(eapi.MOUSE_BUTTON_RIGHT, RMB)
	eapi.BindKey(eapi.MOUSE_BUTTON_MIDDLE, MMB)
	eapi.BindKey(eapi.MOUSE_BUTTON_WHEELUP, Scroll)
	eapi.BindKey(eapi.MOUSE_BUTTON_WHEELDOWN, Scroll)
	
	-- Select first function.
	state.selectedFuncName = next(exports, nil)
	eapi.Log("[Editor] Selected: "..state.selectedFuncName)
	
	CycleCameras(nil, true)
end

local function Parse(filename, world, _exports)
	camera = { }
	camera.ptr = nil
	exports = _exports	-- Set global "exports" table.
	state.filename = filename
	scene = {}		-- Clear any previous parsed/created stuffs.
	
	local fileExists = io.open(filename)
	if not fileExists then
		eapi.Log("[Editor] WARNING: Cannot open '"..filename.."' for parsing.")
	else
		io.close(fileExists)
	end

	if not Cfg.loadEditor then
		-- Editing not requested; simply execute the file.
		if fileExists then
			dofile(filename)
		end
		return
	end

	if next(exports, nil) == nil then
		eapi.Log("[Editor] User function table is empty, '"..filename.."' not parsed.")
		return
	end

	-- Set proxy functions.
	for name, attr in pairs(exports) do
		-- Replace .func attribute with proxy function, so that we
		-- execute the proxy functions when reading saved file.
		attr.userFunc = attr.func
		attr.func = function(...)
			UserProxy(name, ...)
		end
	end

	state.world = world
	state.staticBody = eapi.GetStaticBody(state.world)
	
	if fileExists then
		-- eapi.Log("[Editor] Parsing '"..filename.."'.")
		dofile(filename)
	end
end

-- Editor interface.
editor = {
	Parse=Parse,
	Show=Show
}
return editor
