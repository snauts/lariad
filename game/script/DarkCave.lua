dofile("script/exit.lua")
dofile("script/occlusion.lua")
dofile("script/action.lua")
dofile("script/Cave.lua")
dofile("script/blob.lua")
dofile("script/shape.lua")
dofile("script/Common.lua")

LoadPlayers()
local camBox = {l=-1000,r=7000,b=-144,t=1000}
camera = util.CreateCamera(gameWorld, mainPC, camBox)
eapi.SetBackgroundColor(gameWorld, {r=0.0, g=0.0, b=0.0})

eapi.RandomSeed(1918)

staticBody = eapi.GetStaticBody(gameWorld)

Occlusion.put('f', -600, -64, 10.0, { size={600, 384} })
eapi.NewShape(staticBody, nil, {l=6464, b=-100, r=6564, t=400}, "Box")
eapi.NewShape(staticBody, nil, { b=-50, t=0, l=-50,  r=6500 }, "Box")
eapi.NewShape(staticBody, nil, { b=300, t=350, l=-50,  r=6500 }, "Box")

local rayOfLight = { 'X', 'O', 'G', 'y' }
for j = 0, 3, 1 do
	Occlusion.put('k', 64, j * 64, 0.5)
	Occlusion.put(rayOfLight[j + 1], 97 * 64, j * 64, 0.5)
end

for i = 0, 100, 1 do
	for j = 0, 3, 1 do
		WaterfallTile(SolidRock(), i * 64, j * 64, -1.0)
	end
end

local function DarkColumn(x1, x2)
	for i = x1, x2, 1 do
		for j = 0, 3, 1 do
			Occlusion.put('s', i * 64, j * 64, 0.5)
		end
	end
end

DarkColumn(2, 96)
DarkColumn(98, 100)

for i = 0, 100, 1 do
	Occlusion.put('f', i * 64, -64, 10)
	Occlusion.put('c', i * 64, 3 * 64, 10)
	Occlusion.put('f', i * 64, 4 * 64, 10)
	Occlusion.put('f', i * 64, 5 * 64, 10)
	Occlusion.put('c', i * 64, 0, 10, { flip = { false, true } })
end

for i = 0, 5, 1 do
 	Occlusion.put('b', 0, i * 64, 10)
	Occlusion.put('a', 6400, i * 64, 10)
	Occlusion.put('f', 6464, i * 64, 10)
	Occlusion.put('f', -64, i * 64, 10)
end

local function IsRayOfLightRegion(i) 
	return ((i >= 96 * 64) and (i <= 98 * 64))
end

local function ForCaveLength()
	local i = 0
	while i < 6400 do
		local h = util.Random(0, 64)
		local f = util.ToBeOrNotToBe()
		i = i + util.Random(0, 64)
		if not(IsRayOfLightRegion(i)) then
			if util.ToBeOrNotToBe() then
				Occlusion.RandomStalagmite(i, 2 * 64 + h, 11, f)
			else 
				Occlusion.RandomStalactite(i, -h, 11, f)
			end
		end
	end
end

Occlusion.column()
ForCaveLength()

local leafAnim = eapi.TextureToSpriteList("image/maple-leaf.png", {64,32})

local function LeafColor()
	return {color = { r = 0.8, g = 0.2 + 0.6 * util.Random(), b = 0.2 }}
end

local function FallingLeaf(body)
	local tile = eapi.NewTile(body, {0, 0}, nil, leafAnim, -0.1)
	eapi.SetAttributes(tile, LeafColor())
	eapi.Animate(tile, eapi.ANIM_LOOP, 32, 64.0 * util.Random())
	eapi.SetGravity(body, { x = 0, y = -45 })
end

local function LeafPosition()
	return { 97 * 64 - 16 + 32 * util.Random(), 4 * 64 }
end

local leafInterval = 1
util.ParticleEmitter(LeafPosition, 3.5, leafInterval, FallingLeaf).Kick()

common.Leaf({97 * 64,  -4}, -0.05)
common.Leaf({97 * 64 - 32,  -8}, -0.05)
common.Leaf({97 * 64 + 32,  -12}, -0.05)

local BatSwarm

local function GetGun()
	mainPC.StopInput()
	util.GameMessage(txt.unlock, camera, mainPC.StartInput)
	game.GetState().hasSterling = true
	game.GetState().weaponInUse = "image/sterling.png"
	eapi.PlaySound(gameWorld, "sound/reload.ogg")
	proximity.Tutorial({ l = 96 * 64, t = 96, r = 99 * 64, b = 16 }, 9)
	BatSwarm({l=5299,r=5324,b=2,t=264}, -1)
	blob.Refresh()
end

local function SearchLeaves()
	if not(game.GetState().hasSterling) then
		destroyer.Activate(GetGun)
	end
end

action.MakeActivator({ l=97*64+16, t=3, r=97*64+48, b=1 },
		     SearchLeaves, txt.leafPile)

ExitRoom({ l=32.00, t=400.00, r=33.00, b=0.00 }, "Waterfall", { -650, -3508 },
	 nil, nil, nil, eapi.SLIDE_LEFT)

eapi.PlaySound(gameWorld, "sound/creepy.ogg", -1, 0.9)

local flyBat = eapi.TextureToSpriteList("image/bat.png", {256, 128})

BatSwarm = function(bb, dir)
	dir = dir or 1
	local emitter = nil
	local activator = nil
	local offset = { x = -64, y = -32 }
	local size = { x = 128, y = 64 }
	local vel = { x = -500 * dir, y = -600 }
	local function Pos()
		local pos = eapi.GetPos(mainPC.body)
		return { x = pos.x + dir * 400, y = bb.t }
	end
	local function Bat(body)
		local tile = eapi.NewTile(body, offset, size, flyBat, 1)
		eapi.SetAttributes(tile, { color = util.Gray(0) })
		eapi.Animate(tile, eapi.ANIM_LOOP, 64, util.Random())

		local angle = 30 * (util.Random() - 0.5)
		eapi.SetVel(body, vector.Rotate(vel, angle))

		eapi.SetGravity(body, { x = 0, y = 1000 })
		eapi.AddTimer(body, 1.7, common.BatSound)
		common.BatSound()
	end
	local function ReleaseBats()
		action.DeleteActivator(activator)		
		emitter = util.ParticleEmitter(Pos, 3, 0.05, Bat)
		eapi.AddTimer(staticBody, 2, emitter.Stop)
		emitter.Kick()
	end
	activator = action.MakeActivator(bb, ReleaseBats, nil, staticBody, true)
end

local exports = {
	BatSwarm = {func=BatSwarm,points=2},
	RibCage = {func=common.RibCage,points=1},
	Skull = {func=common.Skull,points=1},
	Blob = {func=blob.Put,points=1}
}
editor.Parse("script/DarkCave-edit.lua", gameWorld, exports)

util.PreloadSound({ "sound/reload.ogg" })
