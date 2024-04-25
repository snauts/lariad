dofile("script/object.lua")

local frogs = {}
local stillFrog = eapi.TextureToSpriteList("image/frog-jump.png", {128, 128})

local function FrogDirection(frog, side)
	frog.dir = (side and -1) or 1
	frog.side = side
end	

local function KickFrog(frog)
	action.StartStepFunction(frog)
	eapi.SetSpriteList(frog.tile, stillFrog)
	action.SetDirection(frog)	

	local function KickFrogCallback()
		eapi.Animate(frog.tile, eapi.ANIM_CLAMP, 24)
		
		frog.vel = { x = frog.dir * (util.Random() * 300 + 200),
			     y = util.Random() * 300 + 300}

		frog.timer = eapi.AddTimer(frog.body, 2 + 2 * util.Random(),
					   KickFrogCallback)
	end
	KickFrogCallback()
end

local function TouchFrog(player, frog)
	if frog.contact.ground then
		eapi.PlaySound(gameWorld, "sound/croak.ogg")	
		eapi.PlaySound(gameWorld, "sound/punch.ogg")	
		FrogDirection(frog, not(player.direction))
		eapi.DelTimer(frog.timer)
		KickFrog(frog)
	end
end

local function FrogShootEffect(actor, projectile)
	effects.Blood(actor.body, projectile)
end

local frogShape  = { l=32, r=96, b=32, t=64 }

local function FrogDie(frog)
	action.Crush(0.3)()
	action.MarkMobDead(frog)
end

local function Put(pos, dir)
	local frog = {
		x		= pos.x,
		y		= pos.y,
		w		= 128,
		h		= 128,
		health		= 1,
		depth		= -0.5,
		dir		= dir,
		name		= "frog",
		side		= (dir < 0),
		shape		= frogShape,
		killZone	= frogShape,
		gravity		= {x=0, y=-1500},
		vel		= {x=0, y=0},
		restingSprite	= stillFrog,
		dieImage	= effects.ShatterImage(128, 0),
		ShootEffect	= FrogShootEffect,
		Activate	= KickFrog,
		pressure	= 700,
		useGibs		= true,
		KillPlayer	= TouchFrog,
		OnDeath		= FrogDie,
	}
	if action.IsMobDead(frog) then return end			
	object.CompleteHalt(frog)
	action.MakeActor(frog)
	frog.MaybeActivate()
end

-- Exported names.
frog = {
	PutFrog = Put
}
return frog
