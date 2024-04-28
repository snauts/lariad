-- all the variables that must be saved must go in here

local function InitTable(count, item)
	local bag = { }
	for i = 1, count, 1 do
		bag[i] = item
	end
	return bag
end

local function NewState()
	return {
	bigWaspDead = false,
	bigSpiderDead = false,
	teleporterFixed = false,
	longTravelCutscene = true,
	dieselStarted = false,
	toolbox = false,
	boulderCutscene = false,
	previousRoom = "",
	currentRoom = "ReedHouse",
	playerPosition = { 0, 0 },
	playerDirection = true,
	spaceShipLandedOn = "swamp-map",
	weaponInUse = nil,
	hasSterling = false,
	playerHidden = false,
	invadersComplete = false,
	gotPDA = false,
	healthPlus = InitTable(7, false),
	tutorial = InitTable(10, false),
	pyramidAmbush = false,
	trainingLevel = 1,
	startLives = Cfg.startLives,
	maxLives = Cfg.startLives,
	lives = Cfg.startLives,
	kills = { },
}
end

local state = NewState()

local function ResetState()
	state = NewState()
end

local function FormatPrimitive(value)
	if type(value) == "nil" then
		return "nil"
	end
	if type(value) == "string" then
		return "\"" .. value .. "\""
	end
	if type(value) == "number" then
		return "" .. value
	end
	if type(value) == "boolean" then
		if value then
			return "true"
		else
			return "false"
		end
	end
	error("unknown type")
end

local function FormatValue(value)
	if type(value) == "table" then
		local str = "{"
		for name, value in pairs(value) do
			if type(name) == "string" then
				str = str .. name .. "="
			end
			str = str .. FormatValue(value) .. ","
		end
		return str .. "}"
	else
		return FormatPrimitive(value)
	end
end

local function Save(key, keyDown)
	if keyDown then
		state.playerPosition = eapi.GetPos(mainPC.body)
		state.playerDirection = mainPC.direction
		local f = io.open("/savedata/saavgaam", "w")
		if f then
			f:write("return ")
			f:write(FormatValue(state))
			f:write("\n")
			io.close(f)
		end
	end
end

local function HasSaavgaam()
	return util.FileExists("/savedata/saavgaam")
end

local function Load(key, keyDown)
	if keyDown then
		if HasSaavgaam() then
			state = dofile("/savedata/saavgaam")
			if not(state.kills) then state.kills = { } end
			util.GoToAndPlace(state.currentRoom, mainPC,
			    state.playerPosition, state.playerDirection)
			destroyer.WeaponUp(mainPC)
		end
	end
end

local items

local function ItemTile(tile)
	return items[tile]
end

local function Init()
	if Cfg.loadEditor then
		eapi.BindKey(eapi.KEY_F9,  Load)
		eapi.BindKey(eapi.KEY_F10, Save)
	end
	items = util.TextureToTileset("image/inventory-items.png", 
				 tileMap8x8, {32, 32})
end

local function GetState()
	return state
end

game = {
	Load = Load,
	Save = Save,
	Init = Init,
	GetState = GetState,
	ItemTile = ItemTile,
	ResetState = ResetState,
	HasSaavgaam = HasSaavgaam,
	FormatValue = FormatValue,
}
return game
