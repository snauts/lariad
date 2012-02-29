dofile("script/object.lua")
dofile("script/action.lua")
dofile("script/Energy.lua")

local stillBoss = eapi.TextureToSpriteList("image/boss.png", {256, 192})
local rage = eapi.TextureToSpriteList("image/boss-rage.png", {256, 192})

local flame1 = eapi.TextureToSpriteList("image/combustion1.png", { 64, 128})
local flame2 = eapi.TextureToSpriteList("image/combustion2.png", {128, 128})

local function BossSideJet(boss, num, offset, flip)
	boss.jet[num] = util.PutAnimTile(boss.body, flame2, 
					 { x = offset, y = -80},
					 0.4, eapi.ANIM_LOOP, 40)
	eapi.SetAttributes(boss.jet[num], { flip = { flip, true } })
end

local function SideJet(boss, num, state)
	if not(boss.jet[num]) and state then
		local offset = (num == 1) and 155 or -20			
		BossSideJet(boss, num, offset, (num == -1))
	end

	if boss.jet[num] and not(state) then
		eapi.Destroy(boss.jet[num])
		boss.jet[num] = nil
	end

end

local function Facing(boss)
	local oldFacing = boss.facing
	boss.facing = action.GetKickDirection(boss)
	if not(boss.facing == oldFacing) then
		eapi.Animate(boss.tile, eapi.ANIM_CLAMP, 16 * boss.facing, 0)
	end
end

local music
util.PreloadSound("sound/boss.ogg")

local function ActivateBoss(boss)
	local target = nil
	progressBar.Init(boss.health)
	music = eapi.PlaySound(gameWorld, "sound/boss.ogg", -1, 1, 2)
	eapi.FadeSound(ambient, 2)

	local flop = false
	local function KickBossCallback()
		if boss.dead then return end
		local actualSide = action.GetKickDirection(boss)
		local pos = eapi.GetPos(boss.body)
		if pos.y < boss.y then
			boss.vel.y = 50
		end
		target = { x = boss.facing * 1000, y = -100 }
		if (boss.facing > 0 and boss.x + 900 > pos.x)
		or (boss.facing < 0 and boss.x - 900 < pos.x) then
			if mainPC.dead then Facing(boss) end
			SideJet(boss, -boss.facing, true)			
			SideJet(boss, boss.facing, false)			
			boss.vel.x = boss.facing * 100
			if actualSide == boss.facing then
				target = nil
			end
		else
			SideJet(boss, -1, false)			
			SideJet(boss,  1, false)			
			boss.vel.x = 0
		end
		if boss.vel.x == 0 then
			target.y = target.y + 250 * util.Random()
		end
		if boss.vel.x == 0 or (util.Random() < 0.7 and flop) then
			energy.Put(vector.Add(pos, {x = 128, y = 96}), target)
		end
		flop = not(flop)
		eapi.AddTimer(boss.body, 0.5, KickBossCallback)
	end
	KickBossCallback()
end

local function KickBoss(boss)
	local tile = boss.tile
	boss.jet = { }
	boss.jet[0] = util.PutAnimTile(boss.body, flame1, 
				   { x = 98, y = -104},
				   0.4, eapi.ANIM_LOOP, 40)
	eapi.SetAttributes(boss.jet[0], { flip = { false, true } })
	Facing(boss)
	
	
	local function Exterminate()
		util.CameraTracking.call(mainPC)
		object.SimpleStep(boss)
		mainPC.StartInput()
		ActivateBoss(boss)		
	end

	local function Answer2()
		util.CameraTracking.call(boss)
		util.GameMessage(txt.willSee, camera, Exterminate)
	end

	local function Answer1()
		util.CameraTracking.call(mainPC)
		util.GameMessage(txt.nothingPersonal, camera, Answer2)
	end

	mainPC.StopInput()
	util.CameraTracking.call(boss)
	util.GameMessage(txt.WTF, camera, Answer1)
end

local function BossShootEffect(actor, projectile)
	effects.Blood(actor.body, projectile, 0.6)
	if actor.isActive and not(actor.dead) then progressBar.Decrement() end
	Facing(actor)
end

local function BossScatter(height)
	return function()
		return { x = 500 * util.Random() - 250,
			 y = height * util.Random() }
	end
end

local function Outro()
	mainPC.StopInput()
	if mainPC.dead then return end
	eapi.AddTimer(staticBody, 3.0, function() util.GoTo("Outro") end)
end

local function FadeOut()
	effects.Fade(0.0, 1.0, 1.0, Outro, nil, 97)
end

local function BossDie(boss)
	if boss.dead then return end
	eapi.FadeSound(music, 4)

	boss.dead = true
	progressBar.Remove()
	eapi.Destroy(boss.tile)
	boss.gravity = { x = 0, y = -1500 }
	boss.tile = eapi.NewTile(boss.body, nil, nil, rage, 0.5)

	for i = -1, 1, 1 do
		if boss.jet[i] then
			eapi.Destroy(boss.jet[i])
		end
	end
	
	local ticks = 0
	local vely = 100
	local function Tremble()
		if action.OnGround(boss) then
			eapi.AddTimer(gameWorld, 1.0, FadeOut)			
			eapi.PlaySound(gameWorld, "sound/bone-crush.wav")
			action.Die(boss)
		else
			if ticks > 5 then 
				effects.Gibs(boss, BossScatter(1000), 1)
				ticks = 0
			end
			boss.vel = { x = 2 * vely, y = vely } 
			eapi.AddTimer(boss.body, 0.1, Tremble)
			ticks = ticks + 1
			vely = -vely
		end
	end
	Tremble()
end

local bossShape = { l=32, r=224, b=64, t=176 }
local bossKillZone = { l=112, r=144, b=-96, t=64 }

local function Put(pos)
	local boss = {
		x		= pos.x,
		y		= pos.y,
		w		= 256,
		h		= 192,
		health		= 60,
		depth		= 0.5,
		side		= false,
		shape		= bossShape,
		killZone	= bossKillZone,
		gravity		= {x=0, y=-100},
		vel		= {x=0, y=0},
		restingSprite	= stillBoss,
		dieImage	= effects.ShatterImage(512, 0),
		ShootEffect	= BossShootEffect,
		Scatter		= BossScatter(1500),
		Die		= BossDie,
		Activate	= KickBoss,
		useGibs		= true,
		sleepless	= true,
	}
	action.MakeKicker({ l = pos.x - 512, r = pos.x + 512 + boss.w,
			    b = pos.y - 256, t = pos.y + 128 + boss.h })
	object.CompleteHalt(boss)
	action.MakeActor(boss)
end

boss = {
	Put = Put,
}
return boss
