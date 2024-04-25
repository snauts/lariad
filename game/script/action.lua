dofile(Cfg.texts or "script/Texts.lua")
dofile("script/object.lua")
dofile("script/occlusion.lua")
dofile("script/Proximity.lua")

local activation = { }

local function RemoveActivatorInfo(activator)
	if activator.info then
		util.Map(eapi.Destroy, activator.info)
	end
	activator.info = nil
end

local function PlayerActivate(world, playerShape, activatorShape, resolve)
	local activator = activation[activatorShape]
	local player = eapi.pointerMap[playerShape]

	if not(activator.info) 
	   and activator.text 
	   and not(game.GetState().playerHidden) then
		activator.info = util.GameInfo(activator.text, camera)
	end
	
	activator.active = true
	player.activator = activator

	if (player.contact.ground and player.Up()) or activator.trigger then
		activator.fn()
	end
end

local function MakeActivator(shape, fn, text, body, trigger)
	local activator = { }
	body = body or staticBody
	activator.fn = fn
	activator.text = text
	activator.trigger = trigger
	activator.shape = eapi.NewShape(body, nil, shape, "Activator")
	activation[activator.shape] = activator
	return activator
end

local function DeleteActivator(activator)
	eapi.Destroy(activator.shape)
	activation[activator.shape] = nil
end

local function MakeMessage(text, box, lines, AfterMsgCallBack, body)
	local function ShowMessage(Continue)
		local function NewContinue()
			if AfterMsgCallBack then
				AfterMsgCallBack()
			end
			Continue()			
		end
		local text = lines
		if type(lines) == "function" then
			text = lines()
		end
		if type(text[1]) == "string" then
			util.GameMessage(text, camera, NewContinue)
		else
			local i = 1
			repeat
				local fn = not(text[i + 1]) and NewContinue
				util.GameMessage(text[i], camera, fn)
				i = i + 1
			until not(text[i])
		end
		return true
	end
	local function Msg()
		destroyer.Activate(ShowMessage)
	end
	return action.MakeActivator(box, Msg, text, body)
end

eapi.Collide(gameWorld, "Player", "Activator", PlayerActivate, 50)

local function Collider(world, shape1, shape2, resolve)
	local collider = eapi.pointerMap[shape2]
	local bullet = weapons.GetProjectile(shape1)
	if collider.shouldSpark then
		local depth = collider.sparkDepth or -0.01
		action.PutHitSpark(weapons.GetPos(bullet), depth)
	end
	collider.Shoot(bullet)
end

local hitSpark = eapi.TextureToSpriteList("image/hit-spark.png", {64, 64})

local function PutHitSpark(pos, depth)	
	local offset = { x = -32, y = -32 }
	local body = eapi.NewBody(gameWorld, pos)
	local tile = eapi.NewTile(body, offset, nil, hitSpark, depth or 0.2)
	eapi.AddTimer(body, 0.25, function() eapi.Destroy(body) end)
	eapi.Animate(tile, eapi.ANIM_CLAMP, 64)
end

local function Center(actor)
	local pos = (actor.body and eapi.GetPos(actor.body)) or actor.pos
	pos.x = pos.x + (actor.w / 2)
	pos.y = pos.y + (actor.h / 2)
	return pos
end

local function IsHarmless(actor)
	return (actor and actor.Lethal and not(actor.Lethal(actor)))
end

local function IsLethal(actor, victim)
	return (actor and actor.Lethal and actor.Lethal(actor, victim))
end

local function Lethal(obj)
	return object.GetVel(obj).y < -20
end

local function KillPlayer(world, playerShape, actorShape, resolve)
	local player = eapi.pointerMap[playerShape]
	local actor = eapi.pointerMap[actorShape]

	if IsHarmless(actor) then return end

	if actor and actor.KillPlayer then
		actor.KillPlayer(player, actor)
	else
		destroyer.FallDeath(player, actor)
	end
end

local function KillActor(world, actorShape, killShape, resolve)
	local actor = eapi.pointerMap[actorShape]
	local killer = eapi.pointerMap[killShape]

	if IsLethal(killer, actor) then
		util.MaybeCall(actor.Kill, actor, killer)
	end
end

local function Touch(world, playerShape, actorShape, resolve)
	local player = eapi.pointerMap[playerShape]
	local actor = eapi.pointerMap[actorShape]
	if actor and not(actor.isActive) then
		util.MaybeCall(actor.TouchInactive, actor, player)
	else
		util.MaybeCall(actor.TouchActive, actor, player)
	end
end

local function OnGround(actor)
	return actor.contact and actor.contact.ground
end

local function MakeActorShape(actor)
	actor.shapeObj = eapi.NewShape(actor.body, nil, actor.shape, 
				       actor.shapeType or "Actor")
	eapi.pointerMap[actor.shapeObj] = actor
end

local function MakeActorKillzone(a)
	if not(a.killZone) then return end
	a.killZoneObj = eapi.NewShape(a.body, nil, a.killZone, "KillerActor")
	eapi.pointerMap[a.killZoneObj] = a
end

--[[
  * actor rests peacefully until it is triggered by proximity of player
  * actor can be shot by player in which case it shatters
  * actor can kill player by touching it
]]--

local function Die(actor)
	local function RandomScatter()
		return { x = actor.pressure * (util.Random() - 0.5),
			 y = actor.pressure *  util.Random() }
	end

	if actor.OnDeath then actor.OnDeath(actor) end
	local fn = actor.Scatter or RandomScatter
	effects.Shatter(actor.dieImage, actor, fn, actor.duration or 2,
			nil, nil, actor.Crumble, nil, actor.shapeLessShatter)
	if actor.useGibs then
		effects.Gibs(actor, fn, actor.gibsDuration)
	end
	actor.Delete()
end

local actorTable = { }

local function MakeActor(actor)
	actor.isActive = false
	actor.side = actor.side or false
	actor.vFlip = actor.vFlip or false
	actor.body = eapi.NewBody(gameWorld, { x = actor.x, y = actor.y })
	if actor.sleepless then
		eapi.SetAttributes(actor.body, { sleep = false })
	end
	actor.tile = eapi.NewTile(actor.body, actor.tileOffset, nil,
				  actor.restingSprite, actor.depth)
	eapi.SetAttributes(actor.tile, { flip = { actor.side, actor.vFlip } })
	eapi.SetFrame(actor.tile, 0)

	actor.Delete = function()
		util.RemoveFromPointerMap(actor.killZoneObj)
		actorTable[actor] = nil
		object.Delete(actor)
	end

	actor.Die = actor.Die or Die

	actor.WakeUp = function()
		MakeActorKillzone(actor)
		actor.Activate(actor)
	end

	local function ShouldWake()
		return not(actor.WakeCondition) or actor.WakeCondition()
	end

	local function MaybeActivate()
		if ShouldWake() and not(actor.isActive) then			
			local delay = actor.wakeupDelay or 0
			eapi.AddTimer(actor.body, delay, actor.WakeUp)
			actor.isActive = true
		end
	end
	actor.MaybeActivate = MaybeActivate

	actor.Shoot = function(projectile)
		MaybeActivate()
		if actor.ShootEffect then
			actor.ShootEffect(actor, projectile)
		end
		actor.health = actor.health - projectile.damage
		weapons.DeleteProjectile(projectile)
		if actor.health <= 0 then
			actor.Die(actor)
		end
	end

	MakeActorShape(actor)
	actorTable[actor] = actor
end

local function MaybeActivate(actor)
	actor.MaybeActivate()
end

eapi.Collide(gameWorld, "Player", "KillerActor", KillPlayer, -100)
eapi.Collide(gameWorld, "Actor", "KillerActor", KillActor, -100)
eapi.Collide(gameWorld, "Player", "Actor", Touch, -110)
eapi.Collide(gameWorld, "Projectile", "Actor", Collider, -100)

object.RegisterHandlers("Actor")

local allWaypoints = { }

local function WayPointHandler(world, waypointShape, actorShape, resolve)
	local actor = eapi.pointerMap[actorShape]
	if actor.WayPointHandler then
		actor.WayPointHandler(actor, allWaypoints[waypointShape])
	end
end

eapi.Collide(gameWorld, "WayPoint", "Actor", WayPointHandler, -100)

local function CreateWaypoint(shape, action)
	local shapeObj = eapi.NewShape(staticBody, nil, shape, "WayPoint")
	allWaypoints[shapeObj] = action
end

local function WaypointFunction(action)
	return function(pos)
		CreateWaypoint({ l = pos.x, r = pos.x + 2,
				 b = pos.y, t = pos.y + 2 },
			       action)
	end
end

local function JumpBackWaypoint(pos)
	CreateWaypointFromPosition(pos, "jump-back")
end

local function LineByLine(lines)
	local collection = { }
	for i = 1, #lines do
		collection[i] = { }
		for j = 1, i do
			collection[i][j] = lines[j]
		end
	end
	return collection
end

local function DistanceToPlayer(actor)
	local body = actor.body
	return eapi.GetPos(mainPC.body).x - eapi.GetPos(body).x - actor.w / 2
end

local function HeightDifference(body)
	return eapi.GetPos(mainPC.body).y - eapi.GetPos(body).y
end

local function ShouldTurn(distance, side)
	return (distance > 0 and side) or (distance < 0 and not(side))
end

local function GetKickDirection(actor)
	local delta = DistanceToPlayer(actor)
	if delta == 0 then
		return 0
	else
		return delta / math.abs(delta)
	end
end

local function SetDirection(actor, tile)
	tile = tile or actor.tile
	local attribute = { flip = { not(actor.side), false } }
	eapi.SetAttributes(tile, attribute)
end

local function Crush(volume)
	return function()
		eapi.PlaySound(gameWorld, "sound/crush.ogg", 0, volume)
	end
end

local function StartStepFunction(actor)
	if not(actor.hasStepFunction) then
		object.SimpleStep(actor)
		actor.hasStepFunction = true
	end
end

local function IsInBoundingBox(actor, bb)
	return actor.body and util.IsInBoundingBox(eapi.GetPos(actor.body), bb)
end

local function Kicker(world, playerShape, kickerShape, resolve)
	local player = eapi.pointerMap[playerShape]
	local bb = eapi.pointerMap[kickerShape]

	for _, actor in pairs(actorTable) do
		if IsInBoundingBox(actor, bb) then
			actor.MaybeActivate()
			actorTable[actor] = nil
		end
	end

	eapi.pointerMap[kickerShape] = nil
	eapi.Destroy(kickerShape)
end

local function MakeKicker(bb)
	local shape = eapi.NewShape(staticBody, nil, bb, "ActorKicker")
	eapi.pointerMap[shape] = bb
end

local function AlternateSounds(filename1, filename2, loudness)
	local coin = (util.Random() > 0.5)
	local file = (coin and filename1) or filename2
	eapi.PlaySound(gameWorld, file, nil, loudness or 1.0)	
end

local function PlayRockCrumbleSound()
	AlternateSounds("sound/pebble1.ogg", "sound/pebble2.ogg")
end

eapi.Collide(gameWorld, "Player", "ActorKicker", Kicker, -100)

local function BlowUp(s)
	s = s or 500
	return function() return { x = s * (util.Random() - 0.5), y = s } end
end

local function Stompable(pos, tile)
	local x = math.floor(pos.x)
	local y = math.floor(pos.y)
	local function Resize(ysize)
		local attrib = { size = { x = 64, y = ysize } }
		eapi.SetAttributes(tile, attrib)
	end
	local function PushDown()
		Resize(62)
	end
	local function PopUp()
		Resize(64)
	end
	local bb = { l = x + 24, b = y + 24, r = x + 40, t = y + 40 }
	proximity.Create(PushDown, PopUp, nil, bb)
end

local function MobName(obj)
	local x = math.floor(obj.x)
	local y = math.floor(obj.y)
	local pos = "_" .. x .. "_" .. y
	local name = game.GetState().currentRoom .. "_" .. obj.name .. pos
	return string.gsub(name, "-", "_")
end

local function IsMobDead(obj)
	return game.GetState().kills[MobName(obj)]
end

local function MarkMobDead(obj)
	game.GetState().kills[MobName(obj)] = true
end

action = {
	MarkMobDead = MarkMobDead,
	IsMobDead = IsMobDead,
	BlowUp = BlowUp,
	Stompable = Stompable,
	AlternateSounds = AlternateSounds,
	RockCrumble = util.WithDelay(0.1, PlayRockCrumbleSound),
	MakeActivator = MakeActivator,
	MakeActorShape  = MakeActorShape,
	MakeActor     = MakeActor,
	MakeMessage   = MakeMessage,
	LineByLine    = LineByLine,
	DeleteActivator = DeleteActivator,
	RemoveActivatorInfo = RemoveActivatorInfo,
	DistanceToPlayer = DistanceToPlayer,
	HeightDifference = HeightDifference,
	GetKickDirection = GetKickDirection,
	ShouldTurn = ShouldTurn,
	SetDirection = SetDirection,
	OnGround = OnGround,
	WaypointFunction = WaypointFunction,
	StartStepFunction = StartStepFunction,
	Crush = Crush,
	MakeKicker = MakeKicker,
	PutHitSpark = PutHitSpark,
	MaybeActivate = MaybeActivate,
	Center = Center,
	Lethal = Lethal,
	Die = Die,
}
return action

