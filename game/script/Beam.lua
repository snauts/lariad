local beamDebris = { l =  -2, r =  2, b =   0, t = 208 }
local beamLethal = { l = -30, r = 30, b = -16, t = -0 }

local beamSize = { { 320 + 1, 0 + 1 }, { 64 - 2, 256 - 2} }
local imgName = { "image/forest-more.png", filter=1 }
local img = eapi.NewSpriteList(imgName, beamSize)

local handlerInit = false

local function BeamBox(top)
	return { l = -32, r = 32, b = -10, t = top or 208 }
end

local function BeamShape(top)
	return { l = -32, r = 32, b = -12, t = top or 208 }
end

local function Put(init)
	local function Fall(actor)
		local function EndFalling()
			if eapi.GetVel(actor.body).y < -500 then
				local pos = eapi.GetPos(actor.body)
				actor.Delete()
				-- delete before creating debris, because
				-- both beam and trash has same shapeType,
				-- otherwise beam shape will push trash aside
				effects.Debris(pos, beamDebris, 25, 0.3)
			end
		end
		actor.Ground = EndFalling
		eapi.SetGravity(actor.body, actor.gravity)
		if actor.vel then
			eapi.SetVel(actor.body, actor.vel)
		end
	end

	local falling = {    w			= 64,
			     h			= 256,
			     name		= "Beam",
			     depth		= 0.5,
			     tileOffset		= { x = -32, y = -32 },
			     gravity		= { x = 0, y = -1500 },
			     shape		= BeamShape(init.top),
			     killZone		= beamLethal,
			     Activate		= Fall,
			     shapeType		= "Object",
			     Lethal		= action.Lethal,
			     restingSprite	= img,
			     contact		= {}
		     }

	falling.Die = function()
		falling.Delete()
	end
	
	falling = util.JoinTables(falling, init)
	object.CompleteHalt(falling)
	action.MakeActor(falling)
	eapi.NewShape(falling.body, nil, BeamBox(init.top), "Box") 
	falling.MaybeActivate()
end

fallBeam = {
	Put = Put,
	img = img,
}
return fallBeam
