dofile("script/object.lua")

local img = eapi.TextureToSpriteList("image/gear.png", { 32, 32 })

local crapInfo = {
	{ common.IndustrialImg({ {  64, 208 }, { 64, 48 } }, true),
	  { x = -32, y = -24 }, 0, 0, 0, 0.51, -8, }, -- holder
	{ common.IndustrialImg({ { 128, 448 }, { 64, 64 } }, true), 
	  { x = -32, y = -32 }, 90, 0, 0, 0.52, }, -- crane
	{ common.IndustrialImg({ {  64, 128 }, { 64, 16 } }, true),
	  { x = -32, y = -8 }, 0, -16, 8,  0.53, },
	{ common.IndustrialImg({ {  64, 144 }, { 64, 16 } }, true),
	  { x = -32, y = -8 }, 0, -16, 8,  0.53, },
	{ common.IndustrialImg({ {  64, 160 }, { 64, 16 } }, true),
	  { x = -32, y = -8 }, 0, -16, 8,  0.53, },
	{ common.IndustrialImg({ {  64, 176 }, { 64, 16 } }, true),
	  { x = -32, y = -8 }, 0, -16, 8,  0.53, },
}

local function KickCrap(actor)
	for i = 1, #crapInfo, 1 do
		local body = actor.crap[i].body
		eapi.SetGravity(body, actor.gravity)
		eapi.SetVel(body, action.BlowUp(400)())
	end
end

local function ScrapMetalActivate(actor, projectile)
	eapi.PlaySound(gameWorld, "sound/clunk.ogg")
	bat.RaiseGroup(actor.groupID)
	KickCrap(actor)
end

local function StepOnCrap(actor, player)
	ScrapMetalActivate(actor)
	actor.Die(actor)
end

local function AddGarbage(scarpMetal)
	for i = 1, #crapInfo, 1 do
		local crap = crapInfo[i]
		local ydelta = crap[4] + math.floor(util.Random() * crap[5])
		local pos = vector.Offset(scarpMetal, 0, ydelta)
		local body = eapi.NewBody(gameWorld, pos)
		local tile = eapi.NewTile(body, crap[2], nil, crap[1], crap[6])
		local randomAngle = 60 * (util.Random() - 0.5)
		local angle = vector.ToRadians(crap[3] + randomAngle)

		local obj = { body = body }
		local shape = { l = -16, r = 16, b = crap[7] or 0, t = 16 }
		obj.shapeObj = eapi.NewShape(obj.body, nil, shape, "Object")
		eapi.pointerMap[obj.shapeObj] = obj
		object.CompleteHalt(obj)

		eapi.SetAttributes(tile, { angle = angle })
		scarpMetal.crap[i] = obj
	end
end

local function Put(pos, groupID)
	local scrapMetal = {
		x		= pos.x,
		y		= pos.y,
		w		= 64,
		h		= 64,
		health		= 1,
		depth		= 0.5,
		pressure	= 500,
		groupID		= groupID,
		tileOffset	= { x = -16, y = -16 },
		shape		= { l = -16, r = 16, b = -16, t = 16 },
		gravity		= { x = 0, y = -1500 },
		TouchActive	= StepOnCrap,
		restingSprite	= img,
		ShootEffect	= ScrapMetalActivate,
		shouldSpark	= true,
		crap		= { },
		dieImage	= "image/gear.png",
		Activate	= function(actor) end,
	}
	object.CompleteHalt(scrapMetal)
	action.MakeActor(scrapMetal)
	scrapMetal.MaybeActivate()
	AddGarbage(scrapMetal)
end

scrapMetal = {
	Put = Put,
}
return scrapMetal
