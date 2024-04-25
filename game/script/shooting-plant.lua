dofile("script/object.lua")

local img = eapi.TextureToSpriteList("image/shooting-plant.png", {64, 256})
local seedImg = common.LoadItem({ { 192, 0 }, { 32, 32 } })

local seedShape = { l = -4, r = 4, b = -4, t = 4 }

local function PlayerPos()
	return eapi.GetPos(mainPC.body).x + mainPC.vel.x
end

local function KickSeed(seed)
	eapi.SetGravity(seed.body, seed.gravity)
	local distance = PlayerPos() - seed.x
	local xspeed = math.max(-400, math.min(400, 0.9 * distance))
	local vel = { x = xspeed, y = 500 }
	eapi.SetVel(seed.body, vel)
end

local function SeedCollide(seed)
	local spores = effects.Smoke(eapi.GetPos(seed.body),
				     { z = 0.15, dim = 0.5, life = 1,
				       disableProximitySensor = true,
				       color = { r = 0.5, g = 0.4, b = 0.1 },
				       inverval = 0.01, variation = 90,
				       vel = { x = 0, y = 70 } })

	local function End()
		spores.Stop()
		seed.Delete()
	end

	util.RemoveFromPointerMap(seed.shapeObj)
	seed.shapeObj = nil
	util.RemoveFromPointerMap(seed.killZoneObj)
	seed.killZoneObj = nil
	eapi.Destroy(seed.tile)

	eapi.PlaySound(gameWorld, "sound/chshsh.ogg")
	eapi.SetGravity(seed.body, vector.null)
	eapi.SetVel(seed.body, vector.null)
	eapi.AddTimer(seed.body, 1, End)
	spores.Kick()	
end

local function Seed(pos)
	local seed = {
		x		= pos.x,
		y		= pos.y,
		w		= 32,
		h		= 32,
		health		= 1,
		depth		= 0.1,
		Collide		= SeedCollide,
		shape		= seedShape,
		killZone	= seedShape,
		tileOffset	= { x = -16, y = -16 },
		gravity		= { x = 0, y = -1000 },
		restingSprite	= seedImg,
		Activate	= KickSeed,
	}	
	eapi.PlaySound(gameWorld, "sound/plop.ogg")
	object.CompleteHalt(seed)
	action.MakeActor(seed)
	seed.MaybeActivate()
	seed.Die = SeedCollide
end

local function KickPlant(plant)
	local function ShootSeed()
		Seed(vector.Offset(plant, 32, 212))
	end
	local function KickPlantCallback()
		local timeout = 2.0 + util.Random()
		local playerx = eapi.GetPos(mainPC.body).x
		if math.abs(playerx - plant.x) < 400 then 
			eapi.Animate(plant.tile, eapi.ANIM_CLAMP, 32)	
			eapi.AddTimer(plant.body, 0.8125, ShootSeed)
		end
		eapi.AddTimer(plant.body, timeout, KickPlantCallback)
	end
	KickPlantCallback()
end

local plantShape = { l = 0, r = 64, b = 0, t = 256 }

local function Put(pos)
	local plant = {
		x		= pos.x,
		y		= pos.y,
		w		= 64,
		h		= 256,
		health		= 5,
		depth		= 0.2,
		shape		= plantShape,
		gravity		= { x = 0, y = 0 },
		restingSprite	= img,
		dieImage	= "image/plant.png",
		Activate	= KickPlant,
	}
	object.CompleteHalt(plant)
	action.MakeActor(plant)
	util.RemoveFromPointerMap(plant.shapeObj)
end

plant = {
	Put = Put,
}
return plant
