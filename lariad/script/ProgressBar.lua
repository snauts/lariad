local barGrades = nil
local progress = nil
local barTile = { }
local occTile = nil
local width = nil
local locX = nil
local locY = nil

local barLight = { r = 1.0, g = 0.0, b = 0.0, a = 1.0 }
local barColor = { r = 0.8, g = 0.0, b = 0.0, a = 1.0 }
local barDark  = { r = 0.6, g = 0.0, b = 0.0, a = 1.0 }

local function RedLine(i, width, x, height, color)
	local attr = { size = { width, height }, color = color }
	barTile[i] = Occlusion.put('h', locX, locY + x, 98.5, attr, camera.ptr)
end

local function RedBar(width)
	RedLine(1, width, -1, 2, barDark)
	RedLine(2, width,  1, 6, barColor)
	RedLine(3, width,  7, 2, barLight)
end

local function Init(count)
	local camSize = eapi.GetSize(camera.ptr)
	barGrades = count
	progress = barGrades
	width = camSize.x - 40
	locX = -camSize.x / 2 + 20
	locY = -camSize.y / 2 + 20
	local attr = { size = { width + 8, 16 }, color = util.dialogColor }
	occTile = Occlusion.put('h', locX - 4, locY - 4, 98, attr, camera.ptr)
	RedBar(width)
end

local function RemoveBar()
	util.Map(eapi.Destroy, barTile)
	barTile = { }
end

local function Remove()
	RemoveBar()
	if occTile then
		eapi.Destroy(occTile)
		occTile = nil
	end
end

local function Decrement()
	RemoveBar()
	progress = math.max(0, progress - 1)
	local newWidth = math.floor(width * progress / barGrades)
	RedBar(math.max(1, newWidth))
end

local liveTiles = { }
local healthSpacing = 4
local healthSize = { x = 16, y = 32 }

local frame = { { 0, 32 }, { 16, 64 } }
local padImg = eapi.NewSpriteList("image/inventory-items.png", frame)

local frame = { { 16, 32 }, { 32, 64 } }
local barImg = eapi.NewSpriteList("image/inventory-items.png", frame)

local function Lives(firstTime)
	if not(firstTime) then
		for i, t in ipairs(liveTiles) do
			eapi.Destroy(t)
		end
	end
	liveTiles = { }
	
	local camSize = eapi.GetSize(camera.ptr)
	local x = -camSize.x / 2 + healthSpacing
	local y =  camSize.y / 2 - 2 * healthSize.y - healthSpacing
	local healthDistance = healthSize.x + healthSpacing

	local function HealthTile(i, img, z)
		local pos = { x = x + i * healthDistance, y = y }
		return eapi.NewTile(camera.ptr, vector.Floor(pos), nil, img, z)
	end

	for i = 0, (game.GetState().maxLives - 1), 1 do		
		liveTiles[i + 1] = HealthTile(i, padImg, 96)
	end

	for i = 0, (game.GetState().lives - 1), 1 do
		local j = game.GetState().maxLives + i + 1
		liveTiles[j] = HealthTile(i, barImg, 96.5)
	end
end

progressBar = {
	Init = Init,
	Remove = Remove,
	Decrement = Decrement,
	Lives = Lives,
}
return progressBar
