util.msg = "Intro"

game.GetState().playerHidden = true
dofile("script/ReedHouse.lua")

local frame = { { 384, 384 }, { 128, 128 } }
local sleeping = eapi.NewSpriteList("image/player-fall.png", frame)

eapi.NewTile(staticBody, { x = -135, y = -90 }, nil, sleeping, 0.6)

local bedPos = { x = -140, y = -97 }
local bedSize = { { 257, 449 }, { 126, 62 } }
local bed = eapi.NewSpriteList({ "image/swamp.png", filter = true }, bedSize)
local tile = eapi.NewTile(staticBody, bedPos, { x = 140, y = 64 }, bed, 0.7)
eapi.SetAttributes(tile, { flip = { true, false } })

local frame = { { 0, 412 }, { 100, 80 } }
local treeTexture = { "image/trees.png", filter = true }
local swampBGSprite = eapi.NewSpriteList(treeTexture, frame)

local pos = { x = -100, y = -140 }
local size = { x = 200, y = 200 }
local tile = eapi.NewTile(staticBody, pos, size, swampBGSprite, -1.9)
eapi.SetAttributes(tile, { color = util.Gray(0.2) })

local frame = { { 0, 800 }, { 200, 200 } }
local stars = eapi.NewSpriteList({ "image/forest-bg.png" }, frame)
local tile = eapi.NewTile(staticBody, pos, nil, stars, -1.8)

local tint = { r = 1.0, g = 1.0, b = 1.0, a = 0.5 }
local attributes = { size = { 800, 480 }, color = tint }
Occlusion.put('f', -400, -240, 1000, attributes, camera.ptr)

-- TODO: continious snore sound, foot-steps fading in
--	 screams of birds, foot-steps fading out...

local function FadeOut()
	effects.Fade(0.0, 1.0, 2.0, nil, nil, 100)
end

eapi.PlaySound(gameWorld, "sound/snore.ogg", -1, 0.5)

local function PlayGrassStep(i, volume)
	local fileName = "sound/grassstep"..i..".ogg"
	return function()
		eapi.PlaySound(gameWorld, fileName, 0, volume or 1.0)
	end
end

local body = eapi.NewBody(gameWorld, { x = 100, y = -95 })
local walkAnim = eapi.TextureToSpriteList("image/shadow.png", {64, 128})
local thiefTile = eapi.NewTile(body, nil, nil, walkAnim, -1.7)
eapi.SetAttributes(thiefTile, { color = { r = 0, g = 0.03, b = 0.08 } })
eapi.Animate(thiefTile, eapi.ANIM_LOOP, 32)

local function MoveThief(vel)
	local attributes = { flip = { vel.x < 0, false } }
	return function()
		eapi.SetVel(body, vel)
		eapi.SetAttributes(thiefTile, attributes)
	end
end

local function StealGull(volume)
	local fileName = "sound/gull.ogg"
	volume = volume or 1.0
	return function()
		local sound = eapi.PlaySound(gameWorld, fileName, 0, volume)
		eapi.FadeSound(sound, 2)
	end
end

util.PreloadSound({ "sound/grassstep1.ogg",
		    "sound/grassstep2.ogg",
		    "sound/snore.ogg",
		    "sound/gull.ogg" })

util.DoEvents({ { 5.0, PlayGrassStep(1, 0.1) },
		{ 0.5, PlayGrassStep(2, 0.2) },
		{ 0.5, PlayGrassStep(1, 0.4) },
		{ 0.5, PlayGrassStep(2, 0.5) },
		{ 0.5, PlayGrassStep(1, 0.7) },
		{ 0.5, PlayGrassStep(2, 0.8) },

		{ 0.0, MoveThief({ x = -100, y = 0 }) },
		{ 0.5, PlayGrassStep(1, 0.8) },
		{ 0.5, PlayGrassStep(2, 0.8) },
		{ 0.5, PlayGrassStep(1, 0.8) },
		{ 0.5, PlayGrassStep(2, 0.8) },
		{ 0.0, MoveThief({ x = 0, y = 0 }) },
		
		{ 0.5, PlayGrassStep(1, 0.8) },
		{ 0.5, PlayGrassStep(2, 0.7) },
		{ 0.5, PlayGrassStep(1, 0.5) },
		{ 0.5, PlayGrassStep(2, 0.4) },
		{ 0.5, PlayGrassStep(1, 0.2) },
		{ 0.5, PlayGrassStep(2, 0.1) },

		{ 1.0, StealGull(1.0) },
		{ 0.8, StealGull(0.8) },
		{ 0.9, StealGull(0.9) },

		{ 2.0, PlayGrassStep(1, 0.1) },
		{ 0.5, PlayGrassStep(2, 0.2) },
		{ 0.5, PlayGrassStep(1, 0.4) },
		{ 0.5, PlayGrassStep(2, 0.5) },
		{ 0.5, PlayGrassStep(1, 0.7) },
		{ 0.5, PlayGrassStep(2, 0.8) },

		{ 0.0, MoveThief({ x = 100, y = 0 }) },
		{ 0.5, PlayGrassStep(1, 0.8) },
		{ 0.5, PlayGrassStep(2, 0.8) },
		{ 0.5, PlayGrassStep(1, 0.8) },
		{ 0.5, PlayGrassStep(2, 0.8) },
 		{ 0.0, MoveThief({ x = 0, y = 0 }) },

		{ 0.5, PlayGrassStep(1, 0.8) },
		{ 0.5, PlayGrassStep(2, 0.7) },
		{ 0.5, PlayGrassStep(1, 0.5) },
		{ 0.5, PlayGrassStep(2, 0.4) },
		{ 0.5, PlayGrassStep(1, 0.2) },
		{ 0.5, PlayGrassStep(2, 0.1) },

		{ 4.0, FadeOut },
		{ 4.0, util.NewGame } })
