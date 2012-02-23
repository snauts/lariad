dofile("script/object.lua")

local img = eapi.TextureToSpriteList("image/buzzsaw.png", {64, 32})

local function PlayBuzzsawSound(buzzsaw)
	local pos1 = eapi.GetPos(mainPC.body)
	local pos2 = eapi.GetPos(buzzsaw.body)
	if (vector.Distance(pos1, pos2) < 512) then
		local handle = eapi.PlaySound(gameWorld, "sound/buzzsaw.ogg")
		eapi.FadeOut(handle, 0.7)
	end
end

local function KickBuzzsaw(buzzsaw)
	local body = buzzsaw.body
	local function KickBuzzsawCallback()
		local pos = eapi.GetPos(body)
		if (buzzsaw.dir > 0 and pos.x > buzzsaw.bb.r)
		or (buzzsaw.dir < 0 and pos.x < buzzsaw.bb.l) then
			buzzsaw.dir = -buzzsaw.dir;
			PlayBuzzsawSound(buzzsaw)
		end
		if not(buzzsaw.fixPos) then
			eapi.SetVel(body, { x = buzzsaw.dir * 100, y = 0 })
		end
		eapi.Animate(buzzsaw.tile, eapi.ANIM_LOOP, buzzsaw.dir * 24)	
		eapi.AddTimer(body, 0.1, KickBuzzsawCallback)
	end
	KickBuzzsawCallback()
end

local function BuzzsawShape(shapeBottom)
	return { l = -24, r = 24, b = shapeBottom or 4, t = 28 }
end

local function Gap(x, y, z, attributes)
	local w = attributes.size.x
	Occlusion.put('c', x, y, z, attributes)
	attributes.size.x = 4
	Occlusion.put('v', x + w, y, z, attributes)
	attributes.flip[1] = true
	Occlusion.put('v', x - 4, y, z, attributes)
end

local function BuzzsawShoot(actor, projectile)
	eapi.PlaySound(gameWorld, "sound/hit-metal.ogg")
	bat.RaiseGroup(actor.groupID)
end

local function BuzzsawSparks(body, vel, z)
	return effects.Sparks(function() return eapi.GetPos(body) end,
			      nil, { z = z, life = 0.5, variation = 60,
				     vel = vel or { x = 0, y = 300 },
				     gravity = { x = 0, y = -500 }, })
end

local function OnDeath(buzzsaw)
	if buzzsaw.sparks then
		buzzsaw.sparks.Stop()
	end
	action.MarkMobDead(buzzsaw)
end

local function Put(bb, z, shapeBottom, groupID, fixPos, sparkVel)
	z = z or -0.2
	local w = bb.r - bb.l
	local xPos = math.floor(bb.l + (fixPos or util.Random()) * w)
	local buzzsaw = {
		x		= xPos,
		y		= bb.b,
		w		= 64,
		h		= 32,
		bb		= bb,
		health		= 2,
		depth		= z,
		pressure	= 500,
		name		= "buzzsaw",
		groupID		= groupID,
		fixPos		= fixPos,
		tileOffset	= { x = -32, y = 0 },
		shape		= BuzzsawShape(shapeBottom),
		dir		= util.Random(1, 2) * 2 - 3,
		killZone	= BuzzsawShape(shapeBottom),
		gravity		= { x = 0, y = -1500 },
		restingSprite	= img,
		ShootEffect	= BuzzsawShoot,
		shouldSpark	= true,
		OnDeath		= OnDeath,
		dieImage	= "image/buzzsaw.png",
		Activate	= KickBuzzsaw,
	}

	local function Attributes(flip)
		return { size = { x = w + 64, y = 4 },
			 flip = { false, flip },
			 color = { a = 0.7 } }
	end

	Gap(bb.l - 32, bb.b - 4, z + 0.05, Attributes(false))
	Gap(bb.l - 32, bb.b - 2, z + 0.05, Attributes(true))
	Gap(bb.l - 32, bb.b, z - 0.05, Attributes(true))

	if action.IsMobDead(buzzsaw) then return end	
	object.CompleteHalt(buzzsaw)
	action.MakeActor(buzzsaw)

	if fixPos then 
		local fileName = "sound/buzzsaw.ogg"
		local handle = eapi.PlaySound(gameWorld, fileName, -1, 0)
		eapi.BindVolume(handle, buzzsaw.body, mainPC.body, 300, 500)	
	end
	
	eapi.AddTimer(buzzsaw.body, 0, buzzsaw.MaybeActivate)

	if sparkVel then
		buzzsaw.sparks = BuzzsawSparks(buzzsaw.body, sparkVel, z - 0.1)
	end
end

buzzsaw = {
	Put = Put,
}
return buzzsaw
