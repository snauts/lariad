local function BlockBox(obj)
	return { l = -20 - obj.edge, r = 20 + obj.edge,
		 b = -24 + obj.bottom, t = 32 + obj.top }
end
local function BlockShape(obj)
	return { l = -21 - obj.edge, r = 21 + obj.edge,
		 b = -24 + obj.bottom, t = 24 + obj.top }
end
local function BlockKillZone(obj)
	return { l = -16 - obj.edge, r = 16 + obj.edge,
		 b = -32 + obj.bottom, t = 16 + obj.top}
end

local function Activate(block)
	eapi.SetGravity(block.body, block.gravity)
	eapi.NewShape(block.body, nil, BlockBox(block), "Box") 
end

local function ShootEffect(actor, projectile)
	local pos1 = eapi.GetPos(actor.body)
	local pos2 = eapi.GetPos(projectile.body)
	local dir = util.Sign(pos1.x - pos2.x)
	eapi.SetVel(actor.body, { x = 100 * dir, y = 0 })
	actor.health = 10	
end

local function Touch(actor, player)
	local pos1 = eapi.GetPos(actor.body)
	local pos2 = eapi.GetPos(player.body)
	local dir = util.Sign(pos1.x - pos2.x)
	eapi.SetPos(actor.body, vector.Offset(pos1, dir, 0))
end

local function Lethal(actor, victim)
	-- HACK: this is ugly, but people liked the fact that
	--       komodos could be smashed agaist the wall
	return action.Lethal(actor) or (victim and victim.name == "komodo")
end

local function Put(init)
	init.top = init.top or 0
	init.edge = init.edge or 0
	init.bottom = init.bottom or 0
	local block = { w		= 64,
			h		= 64,
			health		= 10,
			depth		= 0.5,
			name		= "Cube",
			tileOffset	= { x = -32, y = -32 },
			gravity		= { x = 0, y = -1500 },
			shape		= BlockShape(init),
			killZone	= BlockKillZone(init),
			ShootEffect	= ShootEffect,
			Activate	= Activate,
			TouchActive	= Touch,
			Lethal		= Lethal,
			shouldSpark	= true,
			contact		= { } }
	block = util.JoinTables(block, init)
	object.DampVelocity(block, 0.9)
	action.MakeActor(block)
	block.MaybeActivate()
end

pushBlock = {
	Put = Put,
}
return pushBlock
