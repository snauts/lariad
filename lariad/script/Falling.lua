local fallingShape   = { l=28, r=36, b=0, t=64 }
local fallingSharp   = { l=16, r=48, b=0, t=32 }

local function Put(init)
	if action.IsMobDead(init) then return end
	init.height = init.height or 512
	local function PlayFallingSound()
		if init.sound then 
			eapi.PlaySound(gameWorld, init.sound)
		end
		action.MarkMobDead(init)
	end
	local function FallingFall(actor)
		local function EndFalling()
			effects.Shatter(init.dieImage, actor, action.BlowUp(),
					2.0, nil, nil, init.Crumble)
			PlayFallingSound()
			actor.Delete()
		end
		actor.Ground = EndFalling
		eapi.SetGravity(actor.body, actor.gravity)
	end

	local falling = {    w			= 64,
			     h			= 64,
			     health		= 1,
			     depth		= 0.5,
			     pressure		= 1000,
			     gravity		= {x=0, y=-1500},
			     shape		= fallingShape,
			     killZone		= fallingSharp,
			     Activate		= FallingFall,
			     KillPlayer		= destroyer.ShatterDeath,
			     shouldSpark	= true,
			     OnDeath		= PlayFallingSound,
			     contact		= {}
		     }
	falling = util.JoinTables(falling, init)
	object.CompleteHalt(falling)
	action.MakeActor(falling)
end

falling = {
	Put = Put,
}
return falling
