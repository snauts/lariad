local energyImg = eapi.TextureToSpriteList("image/fire-ball.png", {64, 64})

local maxVelocity = 600
local steepness = 1.7

local function KickEnergy(energy)
	if energy.kicked then return end
	eapi.Animate(energy.tile, eapi.ANIM_LOOP, 32, 0)
	object.SimpleStep(energy)
	
	if energy.target then 
		energy.vel = energy.target
	else
		local playerPos = eapi.GetPos(mainPC.body)
		local energyPos = eapi.GetPos(energy.body)
		energy.vel = vector.Sub(playerPos, energyPos)
		energy.vel.x = steepness * energy.vel.x
		energy.vel.y = math.min(-100, energy.vel.y)
	end
	energy.vel = vector.Normalize(energy.vel, maxVelocity)
	energy.kicked = true
end

local function Collide(energy)
	if action.OnGround(energy) 
	or energy.contact.right
	or energy.contact.left then
		eapi.PlaySound(gameWorld, "sound/explode.ogg")	
		action.Die(energy)
	end
end

local energyShape = { l=-16, r=16, b=-16, t=16 }

local function ReturnEnergyPositionFunction(energy)
	local lastPos = { x = 0, y = 0 }
	return function()
		local pos = energy.body and eapi.GetPos(energy.body)
		lastPos = pos or lastPos
		return lastPos
	end
end

local function SetupEnergySmoke(energy, z)
	energy.smoke = effects.Smoke(ReturnEnergyPositionFunction(energy),
				     { disableProximitySensor = true,
				       color = { r = 0, g = 0, b = 0 },
				       vel = { x = 100, y = 0 },
				       interval = 0.02,
				       variation = 360,
				       life = 0.5,
				       dim = 0.5,
				       z = z - 0.1, })
	energy.OnDeath = energy.smoke.Stop
	energy.smoke.Kick()
end

local function Put(pos, target, z, gravity)
	z = z or 0.3
	local energy = {
		x		= pos.x,
		y		= pos.y,		
		w		= 64,
		h		= 64,
		health		= 5,
		depth		= z,
		duration	= 0.5,
		side		= false,
		shape		= energyShape,
		killZone	= energyShape,
		gravity		= gravity or {x=0, y=0},
		vel		= {x=0, y=0},
		restingSprite	= energyImg,
		shapeLessShatter= true,
		dieImage	= effects.ShatterImage(64, 0),
		pressure	= 300,
		Activate	= KickEnergy,
		target		= target,
		Collide		= Collide,
		tileOffset	= { x = -32, y = -32 },
		sleepless	= true,
	}
	action.AlternateSounds("sound/fireball1.ogg", "sound/fireball2.ogg", .5)
	object.CompleteHalt(energy)
	action.MakeActor(energy)
	SetupEnergySmoke(energy, z)
	energy.WakeUp()
end

energy = {
	Put = Put,
}
return energy
