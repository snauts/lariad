local acid = eapi.TextureToSpriteList("image/acid-drip.png", {64, 256})
local shape = { l = 24, r = 40, b = 0, t = 256 }

local function Put(pos)
	local obj = nil
	local KickAcid
	local count = nil
	local active = false
	local info = { w = 64, h = 256 }
	info.body = eapi.NewBody(gameWorld, pos)
	info.KillPlayer = destroyer.ShatterDeath	
	info.Lethal = function() return true end
	local tile = eapi.NewTile(info.body, { x=0, y=0 }, nil, acid, -2)
	local function RemoveObj()
		eapi.AddTimer(info.body, 1 + util.Random(), KickAcid)
		eapi.pointerMap[obj] = nil
		eapi.Destroy(obj)
	end
	local function CreateObj()
		obj = eapi.NewShape(info.body, nil, shape, "KillerActor")
		eapi.pointerMap[obj] = info		
		eapi.AddTimer(info.body, 3, RemoveObj)
	end
	local function DripSound()
		if action.DistanceToPlayer(info) < 512 then
			eapi.PlaySound(gameWorld, "sound/drip.ogg", 0, 0.5)
		end
		if count > 0 then
			local delay = 0.3 + 0.4 * util.Random()
			eapi.AddTimer(info.body, delay, DripSound)
			count = count - 1
		end
	end
	KickAcid = function()
		eapi.Animate(tile, eapi.ANIM_CLAMP, 24, 0)
		eapi.AddTimer(info.body, 0.5, CreateObj)
		count = 5
		DripSound()
	end
	eapi.AddTimer(info.body, 3 * util.Random(), KickAcid)
end

-------------------------------------------------------------------------------

local img = eapi.TextureToSpriteList("image/acid-drop.png", {64, 64})
local splashImg = eapi.TextureToSpriteList("image/acid-splash.png", {64, 64})

local function Kick(acid)
	eapi.Animate(acid.tile, eapi.ANIM_LOOP, 64, 0)
end

local function Collide(acid)
	if action.OnGround(acid) then
		local offset = acid.tileOffset
		local pos = eapi.GetPos(acid.body)
		local body = eapi.NewBody(gameWorld, pos)
		local tile = eapi.NewTile(body, offset, nil, splashImg, -4.44)
		eapi.PlaySound(gameWorld, "sound/splat.ogg")
		eapi.Animate(tile, eapi.ANIM_CLAMP, 32, 0)
		eapi.AddTimer(body, 1, function() eapi.Destroy(body) end)
		action.Die(acid)
	end
end

local shape = { l=-16, r=16, b=-16, t=16 }

local function Ball(pos, vel)
	local acid = {
		x		= pos.x,
		y		= pos.y,		
		w		= 64,
		h		= 64,
		health		= 4,
		depth		= -4.45,
		duration	= 0.5,
		side		= false,
		shape		= shape,
		killZone	= shape,
		gravity		= { x = 0, y = -1000 },
		restingSprite	= img,
		dieImage	= effects.ShatterImage(0, 0),
		pressure	= 300,
		Activate	= Kick,
		Collide		= Collide,
		tileOffset	= { x = -32, y = -32 },
	}
	object.CompleteHalt(acid)
	action.MakeActor(acid)
	acid.MaybeActivate()
	eapi.SetVel(acid.body, vel)
	eapi.SetGravity(acid.body, acid.gravity)
end

Acid = {
	Put = Put,
	Ball = Ball,
}
return Acid
