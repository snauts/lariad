--[[
	Various utility routines.
--]]

Infinity = 1e+308
smallTileSize = {32, 32}
defaultTileSize = { x = 64, y = 64 }
defaultFontset = nil

showFPS = false

--[[
	String split function from http://lua-users.org/wiki/SplitJoin
]]--
local function Split(str, delim, maxNb)
	-- Eliminate bad cases...
	if string.find(str, delim) == nil then
		return { str }
	end
	if maxNb == nil or maxNb < 1 then
		maxNb = 0    -- No limit
	end
	local result = {}
	local pat = "(.-)" .. delim .. "()"
	local nb = 0
	local lastPos
	for part, pos in string.gfind(str, pat) do
		nb = nb + 1
		result[nb] = part
		lastPos = pos
		if nb == maxNb then break end
	end
	-- Handle the last field
	if nb ~= maxNb then
		result[nb + 1] = string.sub(str, lastPos)
	end
	return result
end

local function ValueInTable(value, table)
	for k, v in pairs(table) do
		if v == value then
			return true
		end
	end
	return false
end

local function Indent(level)
	for i = 2,level do
		io.write("\t")
	end
end

local function PrintTable(tbl, level)
	if not level then
		level = 1
	end

	-- opening bracket
	Indent(level)
	io.write("{\n")
	
	for k, v in pairs(tbl) do
		if type(k) == "table" then
			PrintTable(k, level + 1)
			Indent(level + 1)
			io.write(": ")
		else
			Indent(level + 1)
			io.write(tostring(k), ": ")
		end
		
		if type(v) == "table" then
			PrintTable(v, level + 1)
		else
			io.write(tostring(v), "\n")
		end
	end
	Indent(level)
	io.write("}\n")
end

--[[ Number rounding function from http://lua-users.org/wiki/SimpleRound ]]--
local function Round(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

--[[
	Accepts an array of tile specifications and executes eapi.NewTile() for
	each one of them.

	tiles		Tile data -- an array with each element in the
			form {{X, Y}, sprite}
	tileSize	The tile grid coordinates {X, Y} above are multiplied by
			tile size to get the actual world coordinates. If not
			specified, assumed to be defaultTileSize.
]]--
local function TileBatch(tiles, tileSize)
	tileSize = tileSize or defaultTileSize
	for i, v in ipairs(tiles) do
		local pos = v[1]
		pos = { pos[1] * tileSize[1], pos[2] * tileSize[2] }
		local canvas = {l=0, r=tileSize[1], b=0, t=tileSize[2]}
		eapi.NewTile(nil, pos, canvas, v[2])
	end
end

--[[
	Given a tile map (represented in ASCII) and a tile set
	(ASCII character to sprite mapping) execute eapi.NewTile() for each
	character to make the tiles appear in the game world.

	body		Body object the tiles will be attached to.
	tileMap		Array of strings.
	tileSet		String character to sprite list mapping.
	startPos	Position of the bottom left tile. nil means {0,0}.
	tileSize	Size of the created tiles. Character row and column
			position is multiplied by this and added to startPos to
			get the final world coordinate. nil means
			defaultTileSize.
	depth		Depth, nil = 0.
]]--
local function CreateTiles(body, tileMap, tileset, startPos, tileSize, depth)
	tileSize = tileSize or defaultTileSize
	startPos = startPos or {x=0,y=0}
	depth = depth or 0
	for r, charRow in ipairs(tileMap) do
		for c = 1, #charRow do
			local char = string.sub(charRow, c, c)
			local sprite = tileset[char]
			assert(char == " " or sprite, "Character (" .. char ..
			   ") not found in tileMap.")
			if sprite then
				local pos = {
				    x=startPos.x + (c-1) * tileSize.x,
				    y=startPos.y + (#tileMap-r) * tileSize.y
				}
				eapi.NewTile(body, pos, tileSize, sprite, depth)
			end
		end
	end
end

function RandomElement(list)
	return list[util.Random(1,#list)]
end

function xor (x, y)
	return ((x and not(y)) or (not(x) and y))
end

local function PutTile(body, tileID, tileSet, position, depth)
	return eapi.NewTile(body, position, nil, tileSet[tileID], depth)
end

local function PutTileWithAttribute(body, tileID, tileSet, position, depth, attr)
	local tile = eapi.NewTile(body, position, nil, tileSet[tileID], depth)
	if attr then
		eapi.SetAttributes(tile, attr)
	end
	return tile
end

local function PutAnimTile(body, spritelist, position, depth, animType, FPS, animStartTime)
	local tile = eapi.NewTile(body, position, nil, spritelist, depth)
	eapi.Animate(tile, animType, FPS, animStartTime)
	return tile
end

local function PutSmallTile(body, tileID, tileSet, position, depth)	 
	 eapi.NewTile(body,
                      position,
	              smallTileSize,
	              tileSet[tileID],
                      depth)
end 

--[[
	Chop texture into sprites to create a tileset.

	texture		Image file name or texture object.
	spriteMap	Character rows that "name" each sprite (see below).
	spriteSize	Size of each sprite in pixels.

	Each character in spriteMap corresponds to a rectangular area of the
	texture (a sprite). Returned result is a tileset: a mapping from each
	character that appears in spriteMap to a SpriteList object.

	If a character appears multiple times in the spriteMap, its SpriteList
	has multiple sprites (frames), which is a useful way to group sprites
	for animation.

	So this:
	spriteMap = {
		"abccd ",
		"   xxy"
	}
	
	produces this:
	tileset = {
		a = eapi.NewSpriteList(texture, {{0,0},{32,32}}),
		b = eapi.NewSpriteList(texture, {{32,0},{32,32}}),
		c = eapi.NewSpriteList(texture, {{64,0},{32,32}}, {{96,0},{32,32}}),
		...
	}
]]--
local function TextureToTileset(texture, spriteMap, spriteSize, offset)
	local tileset = {}
	offset = offset or {x=0, y=0}
	
	-- Figure out sprite coordinates and store them in the tileset table.
	for r, charRow in ipairs(spriteMap) do
		for c = 1, #charRow do
			local char = string.sub(charRow, c, c)
			if char ~= " " then
				if tileset[char] == nil then
					tileset[char] = {}
				end
				local texfrag = {
				  {(c-1)*spriteSize[1] + offset.x,
				   (r-1)*spriteSize[2] + offset.y},
				  {spriteSize[1], spriteSize[2]}
				}
				table.insert(tileset[char], texfrag)
			end
		end
	end

	-- Turn sprite coordinates into actual sprite list objects.
	for char, texfrag in pairs(tileset) do
		tileset[char] = eapi.NewSpriteList(texture, unpack(texfrag))
	end
	
	return tileset
end

--[[
	Load font texture, chop it into sprites, and return the SpriteList.

	filename	Image filename.
	spriteSize	Size of each character in pixels.
	
	In the font image, space (32 ascii) character is expected to be the
	first, and tilde (126 ascii) the last. The ordering is left to right.
	If split over multiple lines, the lines are ordered top to bottom.
]]--
local function LoadFont(filename, spriteSize)
	local fontset = {
		spriteList=eapi.TextureToSpriteList(filename, spriteSize),
		spriteSize=spriteSize
	}
	return fontset
end

local fontMap = { }

for i = 0, 255, 1 do
	fontMap[string.char(i)] = string.char(i)
end

fontMap[string.char(0xc4,0x80)] = string.char(128) --Ā
fontMap[string.char(0xc4,0x8c)] = string.char(129) --Č
fontMap[string.char(0xc4,0x92)] = string.char(130) --Ē
fontMap[string.char(0xc4,0xa2)] = string.char(131) --Ģ
fontMap[string.char(0xc4,0xaa)] = string.char(132) --Ī
fontMap[string.char(0xc4,0xb6)] = string.char(133) --Ķ
fontMap[string.char(0xc4,0xbb)] = string.char(134) --Ļ
fontMap[string.char(0xc5,0x85)] = string.char(135) --Ņ
fontMap[string.char(0xc5,0xa0)] = string.char(136) --Š
fontMap[string.char(0xc5,0xaa)] = string.char(137) --Ū
fontMap[string.char(0xc5,0xbd)] = string.char(138) --Ž

fontMap[string.char(0xc4,0x81)] = string.char(144) --ā
fontMap[string.char(0xc4,0x8d)] = string.char(145) --č
fontMap[string.char(0xc4,0x93)] = string.char(146) --ē
fontMap[string.char(0xc4,0xa3)] = string.char(147) --ģ
fontMap[string.char(0xc4,0xab)] = string.char(148) --ī
fontMap[string.char(0xc4,0xb7)] = string.char(149) --ķ
fontMap[string.char(0xc4,0xbc)] = string.char(150) --ļ
fontMap[string.char(0xc5,0x86)] = string.char(151) --ņ
fontMap[string.char(0xc5,0xa1)] = string.char(152) --š
fontMap[string.char(0xc5,0xab)] = string.char(153) --ū
fontMap[string.char(0xc5,0xbe)] = string.char(154) --ž

fontMap[string.char(0xe2,0x86,0x92)] = string.char(156) --→
fontMap[string.char(0xe2,0x86,0x90)] = string.char(157) --←
fontMap[string.char(0xe2,0x86,0x93)] = string.char(158) --↓
fontMap[string.char(0xe2,0x86,0x91)] = string.char(159) --↑

local function ConvertFromUnicode(text)
	local i = 1
	local newText = ""
	repeat
		for count = 3, 1, -1 do
			local unicode = string.sub(text, i, i + count - 1)
			local char = fontMap[unicode]
			if char then
				newText = newText .. char
				i = i + count
				break
			end
		end
	until #text < i
	return newText
end

--[[
	Create text tiles that are attached to camera viewport.

	text		Text string.
	camera		Camera pointer.
	screenPos	Screen is mapped like so:
			{-1, 1}   {0, 1}   {1, 1}

			{-1, 0}   {0, 0}   {1, 0}

			{-1,-1}   {0,-1}   {1,-1}

			If nil, {0,0} (screen center) is used. Other values than
			-1, 0, 1 are possible and produce in-between positions.
	depth		Depth determines drawing order. Defaults to 100.
	fontset		Font sprite list as returned by LoadFont(). If nil,
			defaultFontset is used.
--]]

local black = { r = 0, g = 0, b = 0 }

local function CreateViewportLines(lines, body, pos)
	local fontset = defaultFontset
	local function PutChar(p, color, z)
		local tile = eapi.NewTile(body, p, nil, fontset.spriteList, z)
		if color then eapi.SetAttributes(tile, {color = color}) end
		return tile
	end

	local ink = nil
	local textTiles = {}
	pos.y = pos.y - fontset.spriteSize[2]
	for r, line in ipairs(lines) do
		if type(line) == "table" then
			ink = line.ink
			line = line.str
		else
			ink = nil
		end
		local leftSide = pos.x
		for c = 1, #line do
			local char = string.sub(line, c, c)
			local rpos = vector.Round(pos)
			local tile1 = PutChar(rpos, ink, 100)
			local shadowPos = vector.Add(rpos, { x = 1, y = -1})
			local tile2 = PutChar(shadowPos, black, 99)
			
			-- Choose the right sprite (frame) from list for char.
			char = string.byte(char, 1)
			if char < 32 or char > 159 then
				print("Character", char, "not in fontset.")
				char = string.byte("?", 1)
			end
			eapi.SetFrame(tile1, char - 32);
			eapi.SetFrame(tile2, char - 32);
			
			pos.x = pos.x + fontset.spriteSize[1]
			table.insert(textTiles, tile1)
			table.insert(textTiles, tile2)
		end
		pos.x = leftSide
		pos.y = pos.y - fontset.spriteSize[2]
	end

	return textTiles
end

local function MaxWidth(lines)
	local maxWidth = 0
	for i, line in ipairs(lines) do
		if type(line) == "table" then 
			lines[i].str = ConvertFromUnicode(line.str)
			maxWidth = math.max(#lines[i].str, maxWidth)
		else
			lines[i] = ConvertFromUnicode(line)
			maxWidth = math.max(#lines[i], maxWidth)
		end
	end
	return maxWidth
end		
		
local dialogColor = { r = 0.35, g = 0.35, b = 0.35, a = 0.65 }

local function GameMsgLoc(totalSize, boxSize, axis)
	return  (totalSize - boxSize) / ((axis == "x" and 2) or 4)
end

local function DialogBox(lines, camera, calcPos, boxW, color)
	local x, y
	calcPos = calcPos or GameMsgLoc

	local camSize = eapi.GetSize(camera.ptr)
	local width = defaultFontset.spriteSize[1] * MaxWidth(lines) + 16
	local boxH = defaultFontset.spriteSize[2] * #lines + 16
	boxW = boxW or width

	if type(calcPos) == "table" then
		x = calcPos.x
		y = calcPos.y
	else
		x = calcPos(camSize.x, boxW, "x")
		y = calcPos(camSize.y, boxH, "y")
	end

	local body = camera.ptr
	x = x - camSize.x / 2
	y = camSize.y / 2 - y

	local attr = { size = { boxW, boxH }, color = color or dialogColor }
	local back = Occlusion.put('h', x - 8, y - boxH + 8, 98, attr, body)
	local textPos = { x = x + 0.5 * (boxW - width), y = y }
	local tiles = CreateViewportLines(lines, body, textPos)
	table.insert(tiles, back)
	return tiles
end

local emptyDummy = { }
local dialogBoxShowing = false
local dialogBoxQueue = { tail = emptyDummy, head = emptyDummy }

local function GameMessage(lines, camera, Trigger)
	if dialogBoxShowing then
		dialogBoxQueue.tail.next = { }
		dialogBoxQueue.tail.lines = lines
		dialogBoxQueue.tail.camera = camera
		dialogBoxQueue.tail.trigger = Trigger
		dialogBoxQueue.tail = dialogBoxQueue.tail.next
	else
		dialogBoxShowing = { }
		dialogBoxShowing.trigger = Trigger
		dialogBoxShowing.tiles = DialogBox(lines, camera)
	end
end

local function MessageDone()
	if dialogBoxShowing then
		local trigger = dialogBoxShowing.trigger
		util.Map(eapi.Destroy, dialogBoxShowing.tiles)
		dialogBoxShowing = false
		if trigger then trigger() end
		if dialogBoxQueue.head.lines then
			local head = dialogBoxQueue.head
			dialogBoxQueue.head = dialogBoxQueue.head.next
			GameMessage(head.lines, head.camera, head.trigger)
		end
	end
end

local function MakeMessageFinish(fn)
	return function(key, keyDown)
		if keyDown then
			MessageDone()
		end
		if fn then 
			fn(key, keyDown)
		end
	end
end

local function GameInfoLocation(totalSize, boxSize, axis)
	return totalSize - ((axis == "x" and boxSize) or 32)
end

local function GameInfo(line, camera)
	return DialogBox({ line }, camera, GameInfoLocation)	
end

--[[
	Create FPS text tiles and return an array of their pointers.

	camera		Camera pointer as returned by eapi.NewCamera().
]]--
local function CreateFPSText(camera)
	local FPS, FPSText
	
	FPS = eapi.GetFPS()
	FPSText = "FPS: " .. FPS .. " Bodies: " .. eapi.GetBodyCount()
	FPSText = FPSText .. string.rep(" ", 9-#FPSText)

	return DialogBox({ FPSText }, camera, { x = 16, y = 16 })
end

local CameraTracking = { }

local function CreateCamera(world, obj, boundary, SomeFunction)
	local camera = {}
	local pos = nil
	local track = nil
	local offset = 0
	local first = true
	local stops = { }
	local stopRange = 350
	local speed = 1

	CameraTracking.call = function (value)
		track = value
	end

	CameraTracking.stop = function (id, value)
		stops[id] = value
	end
	
	if doNotInitCamera then return end
	if type(obj) == "table" then
		if obj.id == "player" then
			pos = eapi.GetPos(obj.body)
			track = obj
		else
			pos = obj
		end
	end
	
	camera.ptr = eapi.NewCamera(world, pos, nil, nil)
	camera.size = eapi.GetSize(camera.ptr)
	if boundary then
		eapi.SetBoundary(camera.ptr, boundary)
	end

	local function GetTargetPosition()
		local s = eapi.GetSize(camera.ptr)
		local p = eapi.GetPos(track.body)
		local qx = (track.direction and -0.25) or 0.25
		local qy = (track.ducked and -0.1) or 0.2
		return vector.Offset(p, s.x * qx, s.y * qy)
	end

	local function CheckStopPoints(c, target)
		for i in pairs(stops) do
			local x1 = vector.Distance(c, stops[i])
			local x2 = vector.Distance(target, stops[i])
			if x1 < stopRange and x2 <= x1 then return true end
		end
		return false
	end

	local function GetTrackVelocity()
		if track.contact and track.contact.platform then
			return track.contact.platform.vel
		else
			return track.vel
		end
	end

	local function CameraAfterStep()
		-- In after-step function, we get the updated body position
		-- after collision handlers have run.
		if type(track) == "userdata" then
			eapi.SetPos(camera.ptr, eapi.GetPos(track))
		elseif track and first then
			eapi.SetPos(camera.ptr, GetTargetPosition())
			first = false
		elseif track then
			local target = GetTargetPosition()
			local stepSec = eapi.GetData(world).stepSec
			local delta = vector.Scale(GetTrackVelocity(), stepSec)
			local c = vector.Add(eapi.GetPos(camera.ptr), delta)
			local diff = vector.Sub(c, target)
			local len = vector.Length(diff)

			if len > 1.0 then
				local amount = math.max(0, 1 - speed * stepSec)
				local newLen = math.max(1.0, amount * len)
				local scaled = vector.Normalize(diff, newLen)
				target = vector.Add(target, scaled)
			end

			if CheckStopPoints(c, target) then return end

			eapi.SetPos(camera.ptr, target)
		end
		
		if camera.FPSTextTiles then
			-- Destroy previous FPS text.
			util.Map(eapi.Destroy, camera.FPSTextTiles)
			camera.FPSTextTiles = nil
		end
		if showFPS then
			camera.FPSTextTiles = CreateFPSText(camera)
		end

		if SomeFunction then
			SomeFunction()
		end
	end
	
	eapi.SetStepFunc(camera.ptr, nil, CameraAfterStep)

	return camera
end

local function BindKeys(keys, fn)
	for _, v in pairs(keys) do
		if v then eapi.BindKey(v, fn) end
	end
end

local function BindAllKeys(fn)
	for key = 1, eapi.SDLK_LAST + 299, 1 do
		eapi.BindKey(key, fn)
	end
end

local function BindDebugKeys()
	local function ShowEditor(key, keyDown)
		if keyDown then
			editor.Show()
		end
	end
	eapi.BindKey(eapi.KEY_F2, ShowEditor)

	local function ToggleDebugState(key, keyDown)
		local stateMap = {
			[eapi.KEY_F5]="drawShapes",
			[eapi.KEY_F6]="drawTileTree",
			[eapi.KEY_F7]="drawShapeTree",
			[eapi.KEY_F8]="outsideView"
		}
		if keyDown then
			local prevState = eapi.GetState(stateMap[key])
			eapi.SetState(stateMap[key], not prevState)
		end
	end
	eapi.BindKey(eapi.KEY_F5, ToggleDebugState)
	eapi.BindKey(eapi.KEY_F6, ToggleDebugState)
	eapi.BindKey(eapi.KEY_F7, ToggleDebugState)
	eapi.BindKey(eapi.KEY_F8, ToggleDebugState)
	eapi.BindKey(eapi.KEY_F4,
	    function(_, keyDown) if keyDown then showFPS = not showFPS end end)

	local function Reset(key, keyDown)
		if keyDown then
			eapi.Clear()
			dofile("script/first.lua")
		end
	end
	eapi.BindKey(eapi.KEY_F12, Reset)
end

local function CreateSimplePlatform(pos, velocity,
				    TilesAndShape,
				    controllable)
	local platform = {}
	platform.ctrl = controllable
	platform.body = eapi.NewBody(gameWorld, pos)
	platform.vel = (platform.ctrl and {x=0, y=0}) or velocity
	local bounds = TilesAndShape(platform)

	local function PlatformStep(world)
		local worldData = eapi.GetData(world)
		local stepSec = worldData.stepSec
		local pos = eapi.GetPos(platform.body)

		local deltaPos = vector.Scale(platform.vel, stepSec)
		pos = vector.Add(pos, deltaPos)

		if (pos.x >= bounds.r or pos.y >= bounds.t)
		    or (pos.x <= bounds.l or pos.y <= bounds.b) then
			if platform.ctrl then 
				platform.vel = { x = 0, y = 0 }
				eapi.SetStepFunc(platform.body, nil, nil)
				if type(platform.ctrl) == "function" then
					platform.ctrl(platform)
				end
			else
				platform.vel = vector.Reverse(platform.vel)
			end
		end

		-- Set new platform position, and get the actual moved (rounded)
		-- unit distance from engine.
		eapi.SetPos(platform.body, pos)
		deltaPos = eapi.GetDeltaPos(platform.body)
		
		-- Apply position difference to each child.
		local children = eapi.GetChildren(platform.body)
		for index, child in ipairs(children) do
			local childPos = eapi.GetPos(child)
			eapi.SetPos(child, vector.Add(childPos, deltaPos))
		end
	end

	platform.up = function()
		platform.vel = velocity
		eapi.SetStepFunc(platform.body, PlatformStep, nil)
	end
	platform.down = function()
		platform.vel = vector.Reverse(velocity)
		eapi.SetStepFunc(platform.body, PlatformStep, nil)
	end

	eapi.pointerMap[platform.shape] = platform;
	eapi.SetStepFunc(platform.body, PlatformStep, nil)

	return platform
end

local function ToBeOrNotToBe()
	if (util.Random() > 0.5) then
		return true
	else
		return false
	end		
end

tileMap8x8 = { "abcdefgh",
	       "ijklmnop",
	       "qrstuvwx",
	       "yzABCDEF",
	       "GHIJKLMN",
	       "OPQRSTUW",
	       "XYZ12345",
	       "67890!@#" }

local function ParticleInterval(avgInterval)
	-- maybe gausian distribution would be better, 
	-- but it involves lots of maths therefore for now
	-- just return random value in interval [ 0; 2*avgInterval ]
	return 2.0 * util.Random() * avgInterval
end

local function ParticleEmitter(origin, life, avgInterval, configure)
	local body = nil
	local emitter = { }
	local function NewParticle()
		if emitter.active then
			eapi.SetPos(body, origin())
			local particle = eapi.NewBody(gameWorld, origin())
			eapi.SetAttributes(particle, { sleep = false })
			local function ParticleRipper()
				eapi.Destroy(particle)
			end
			configure(particle)
			eapi.AddTimer(particle, life, ParticleRipper)
			local interval = ParticleInterval(avgInterval) 
			eapi.AddTimer(body, interval, NewParticle)
		end
	end

	emitter.Kick = function()
		local oldState = emitter.active
		emitter.active = true
		if not(oldState) then
			body = eapi.NewBody(gameWorld, origin())
			NewParticle()
		end
	end

	emitter.Stop = function()
		emitter.active = false
		eapi.Destroy(body)
	end

	return emitter
end

local function Click()
	eapi.PlaySound(gameWorld, "sound/click.ogg", 0, 0.2)
end

-- A function that is supposed to be bound to menu key (escape) and will display
-- the menu once executed.
local function ShowMenu(key, keyDown, gameOver, items)
	if not keyDown then
		return
	end
	
	-- Pause game world and save game keys.
	eapi.Pause(gameWorld)
	local keyBind = eapi.GetKeyBindings()
	
	if not gameOver then
		-- Bind a function to escape key that destroys the menu.
		local function HideMenu(key, keyDown)
			if key and (not keyDown) then
				return
			end
			
			-- Destroy menu and restore game key bindings.
			menu.Kill()
			eapi.SetKeyBindings(keyBind)
			Click()
		end
		BindKeys(Cfg.keyESC, HideMenu)
		eapi.BindKey(eapi.KEY_ESCAPE, HideMenu)
		
		-- Display menu.
		menu.Show(HideMenu, nil, nil, items)
		Click()
	else
		-- Game over, unbind escape key and display menu without resume
		-- option.
		BindKeys(Cfg.keyESC, nil)
		eapi.BindKey(eapi.KEY_ESCAPE, nil)
		menu.Show(nil, nil, nil, items)
	end
end

-- Game-over sequence.
local function GameOver()
	local keyBind = eapi.GetKeyBindings()
	eapi.SetKeyBindings({})		-- Unbind keys, disable all input.

	local world = eapi.NewWorld("Game Over", 5, 11)
	local camera = CreateCamera(world, nil, nil, nil)
	local dimLevel = 0
	local function DimLights()
		dimLevel = dimLevel + 0.01
		if dimLevel >= 0.5 then
			-- Destroy this "darkening" world, restore key
			-- bindings and show game-over menu.
			eapi.Destroy(world)
			eapi.SetKeyBindings(keyBind)
			ShowMenu(nil, true, true)
			return
		end
		eapi.SetBackgroundColor(world, {r=0,g=0,b=0,a=dimLevel})
		eapi.AddTimer(world, 0.02, DimLights)
	end
	eapi.AddTimer(world, 0.02, DimLights)
end

local Message = nil

-- Wipe engine-side and client-side state and execute a script file.
local function GoTo(roomName, TransitionFunc, disableESCAPE, fadeEffect)
	eapi.SwitchFramebuffer()
	eapi.Clear()			-- Clear state.

	emptyDummy = { }
	dialogBoxQueue = { tail = emptyDummy, head = emptyDummy }
	dialogBoxShowing = false
	
	-- Create game world with 5 millisecond step.
	gameWorld = eapi.NewWorld("Game", 5, 16)

	defaultFontset = LoadFont("image/default-font.png", {8,16})
	if Cfg.loadEditor then
		BindDebugKeys()
	end
	game.Init()

	game.GetState().previousRoom = game.GetState().currentRoom
	game.GetState().currentRoom = roomName

	-- Bind a function to escape key that creates the menu.
	if not(disableESCAPE) then
		BindKeys(Cfg.keyESC, util.ShowMenu)
		eapi.BindKey(eapi.KEY_ESCAPE, util.ShowMenu)
	end

	effects.Init()
	weapons.Init()
	
	dofile("script/" .. roomName .. ".lua")
	dofile("script/ProgressBar.lua")

	if TransitionFunc then
		TransitionFunc()
	end
	eapi.FadeFramebuffer(fadeEffect or eapi.CROSSFADE)
	util.PreloadSound({ "sound/click.ogg",
			    "sound/fire.ogg",
			    "sound/error.ogg",
			    "sound/clang.ogg",
			    "sound/crush.ogg",
			    "sound/stone.ogg",
			    "sound/splat.ogg",
			    "sound/steam.ogg",
			    "sound/snarl.ogg",
			    "sound/squirt.ogg",
			    "sound/spider1.ogg",
			    "sound/spider2.ogg",
			    "sound/explode.ogg",
			    "sound/pebble1.ogg",
			    "sound/pebble2.ogg",
			    "sound/powerup.ogg",
			    "sound/bubbling.wav",
			    "sound/sterling.wav",
			    "sound/ricochet.ogg",
			    "sound/generator.ogg",
			    "sound/fireball1.ogg",
			    "sound/fireball2.ogg",
			    "sound/water-drop.ogg",
			    "sound/squish.wav" })
	Message = nil
end

local function GoToAndPlace(room, player, pos, flip, fadeEffect)
	local function PlacePC()
		destroyer.Place(player, pos, flip)
	end
	GoTo(room, PlacePC, nil, fadeEffect)
end

local function FileExists(n)
	local f = io.open(n)
	if f == nil then
		return false
	else
		io.close(f)
		return true
	end
end

local function randomerror(a, b)
	a = a or "nil"
	b = b or "nil"
	print("Error in unil.random(" .. a .. ", " .. b .. ")")
	eapi.Quit()
end

local function Random(a, b)
	local rnd = eapi.Random() / 2147483648
	if a then
		if not(b) then
			b = a
			a = 1
		end
		if (a > b) then 
			randomerror(a, b)
		end
		return math.floor(rnd * (b - a + 1)) + a
	elseif b then
		randomerror(a, b)
	else
		return rnd
	end
end

local function RemoveFromPointerMap(obj)
	if obj then 
		eapi.Destroy(obj)
		eapi.pointerMap[obj] = nil
	end
end

local function IsInBoundingBox(pos, bb)
	return pos.x > bb.l
           and pos.x < bb.r
	   and pos.y > bb.b
	   and pos.y < bb.t
end

local function JoinTables(a, b)
	local result = { }
	for i, v in pairs(a) do
		result[i] = v
	end
	for i, v in pairs(b) do
		result[i] = v
	end
	return result
end

local lastTime = -1
local function WithDelay(delay, FN)
	return function()
		local now = eapi.GetTime(staticBody)
		if math.abs(now - lastTime) < delay  then return end
		lastTime = now
		FN()
	end
end

local function Sign(val)
	return (((val > 0) and 1) or -1)
end

local function CallOrVal(obj)
	if type(obj) == "function" then
		return obj()
	else
		return obj
	end
end

local function MaybeCall(fn, ...)
	if fn then fn(...) end
end

local function Gray(level)
	return { r = level, b = level, g = level }
end

local function Noop()
end

local function Lerp(a, b, q)
	return b + (a - b) * q 
end

local function LerpFn(q)
	return function(a, b) return Lerp(a, b, q) end
end

local function Map(Fn, a, b)
	if a == nil then return nil end

	local new = { }
	for i, _ in pairs(a) do
		new[i] = (b and Fn(a[i], b[i])) or Fn(a[i])
	end
	return new
end

local function Member(item, table)
	for _, v in pairs(table) do
		if item == v then return true end
	end 
	return false
end

local function LerpColors(a, b, q)
	return Map(LerpFn(q), a, b)
end

local function PreloadSound(file)
	if type(file) == "table" then
		for _, str in pairs(file) do
			PreloadSound(str)
		end
	else
		handle = eapi.PlaySound(gameWorld, file, 0, 0)
		eapi.StopSound(handle)
	end
end

local function AnimateTable(tiles, type, fps, start)
	for i, tile in pairs(tiles) do
		eapi.Animate(tile, type, fps, start)
	end
end

local function NewGame()
	game.ResetState()
	util.GoToAndPlace("ReedHouse", mainPC, {-80, -68}, false)
	effects.Fade(1.0, 0.0, 3.0, nil, nil, 100)
	mainPC.StopInput()
	local Hide = proximity.Tutorial({l=-100, b=-70, r=-85, t=-60}, 1)
	local function Resume()
		proximity.Tutorial({l=-100, b=-70, r=-85, t=-60}, 2)
		mainPC.StartInput()
		Hide()
	end
	util.GameMessage(txt.startupInfo, camera, Resume)
end

local function SaveSetup()
	local f = io.open("setup.lua", "w")
	if f then
		local Format = game.FormatValue
		f:write("Cfg.texts=\""..Cfg.texts.."\"\n")
		f:write("Cfg.keyUp="..Format(Cfg.keyUp).."\n")
		f:write("Cfg.keyDown="..Format(Cfg.keyDown).."\n")
		f:write("Cfg.keyLeft="..Format(Cfg.keyLeft).."\n")
		f:write("Cfg.keyRight="..Format(Cfg.keyRight).."\n")
		f:write("Cfg.keyShoot="..Format(Cfg.keyShoot).."\n")
		f:write("Cfg.keyJump="..Format(Cfg.keyJump).."\n")
		f:write("Cfg.keyESC="..Format(Cfg.keyESC).."\n")
		io.close(f)
	end
end

local function KeyName(table)
	for _, v in pairs(table) do
		if v and not(v == 0) then
			return eapi.KeyNames[v] or "?"
		end
	end
	return "?"
end

local function DoEvents(events, body)
	local i = 1
	body = body or staticBody
	local function Do()
		events[i][2]()
		i = i + 1
		if events[i] then 
			local delta = events[i][1]
			eapi.AddTimer(body, delta, Do)
		end
	end
	eapi.AddTimer(body, events[1][1], Do)
end

local function Tik()
	eapi.PlaySound(gameWorld, "sound/tik.ogg", 0, 0.2)		
end

util = {
	Click = Click,
	Tik = Tik,
	DoEvents = DoEvents,
	Member = Member,
	Map = Map,
	NewGame = NewGame,
	SaveSetup = SaveSetup,
	AnimateTable = AnimateTable,
	PreloadSound = PreloadSound,
	LerpColors = LerpColors,
	BindDebugKeys = BindDebugKeys,
	CreateCamera = CreateCamera,
	CreateFPSText = CreateFPSText,
	CreateTiles = CreateTiles,
	FileExists = FileExists,
	GoTo = GoTo,
	GoToAndPlace = GoToAndPlace,
	GameOver = GameOver,
	ShowMenu = ShowMenu,
	PrintTable = PrintTable,
	PutAnimTile = PutAnimTile,
	PutSmallTile = PutSmallTile,
	PutTile = PutTile,
	PutTileWithAttribute = PutTileWithAttribute,
	Round = Round,
	Split = Split,
	TextureToTileset = TextureToTileset,
	TileBatch = TileBatch,
	ValueInTable = ValueInTable,
	ToBeOrNotToBe = ToBeOrNotToBe,
	ParticleEmitter = ParticleEmitter,
	CreateSimplePlatform = CreateSimplePlatform,
	GameMessage = GameMessage,
	GameInfo = GameInfo,
	Message = Message,
	MessageDone = MessageDone,
	MakeMessageFinish = MakeMessageFinish,
	Random = Random,
	map8x8 = tileMap8x8,
	CameraTracking = CameraTracking,
	DialogBox = DialogBox,
	CreateViewportLines = CreateViewportLines,
	dialogColor = dialogColor,
	MaxWidth = MaxWidth,
	RemoveFromPointerMap = RemoveFromPointerMap,
	IsInBoundingBox = IsInBoundingBox,
	JoinTables = JoinTables,
	WithDelay = WithDelay,
	Sign = Sign,
	CallOrVal = CallOrVal,
	MaybeCall = MaybeCall,
	BindKeys = BindKeys,
	BindAllKeys = BindAllKeys,
	KeyName = KeyName,
	Noop = Noop,
	Gray = Gray,
}
return util
