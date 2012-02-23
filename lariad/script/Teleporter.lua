local doorTile

local tPos

local function Put(x, y, fn, flip, useChain)
	flip = flip or false
	local flipInt = (flip and 1) or 0
	tPos = { x = x + ((flip and -64) or 64), y = y }
	util.CameraTracking.stop("teleport", 
				 flip and { x = x - 150, y = y + 150 }
				       or { x = x + 450, y = y + 150 })

	local img = eapi.NewSpriteList("image/teleporter.png", 
				       {{0, 0}, {320, 300}})
	local tile = eapi.NewTile(staticBody, { x, y }, { 320, 300 }, img, 2)
	eapi.SetAttributes(tile, { flip = { flip, false } })
	
	if useChain then
		img = eapi.NewSpriteList("image/teleporter-chain.png",
					 {{0, 0}, {44, 230}})
		tile = eapi.NewTile(staticBody, { x + 80, y + 200 },
				    { 44, 230 }, img, -2)		
	else		
		img = eapi.NewSpriteList("image/teleporter-support.png",
					 {{0, 0}, {320, 150}})
		tile = eapi.NewTile(staticBody, { x, y },
				    { 320, 150 }, img, -2)		
	end

	img = eapi.TextureToSpriteList("image/teleporter-door.png", {160, 300})
	doorTile = eapi.NewTile(staticBody, { x + flipInt * 160, y },
				{ 160, 300 }, img, -2)
	eapi.SetAttributes(doorTile, { flip = { flip, false } })
	eapi.SetFrame(doorTile, 31)

	local function offsetX(q)
		if flip then
			return x + 320 - q
		else
			return x + q
		end
	end

	shape.Line({ offsetX(20), y }, { offsetX(150), y + 120 })
	shape.Line({ offsetX(150), y }, { offsetX(280), y + 120 }, "Box")
	shape.Line({ offsetX(150), y + 265 }, { offsetX(265), y + 400 }, "Box")
	shape.Line({ offsetX(265), y }, { offsetX(400), y + 400 }, "Box")
	
	local x1 = offsetX(250)
	local x2 = offsetX(265)
	action.MakeActivator({l = math.min(x1, x2),
			      r = math.max(x1, x2),
			      b = y + 130, t = y + 140},
			     fn, txt.teleporter)
end

local function AnimateDoor(fps)
	eapi.Animate(doorTile, eapi.ANIM_CLAMP, fps, 0)
end

local function CloseDoor()
	AnimateDoor(-24)
end

local function OpenDoor()
	AnimateDoor(24)
end

local function DoorShut()
	eapi.SetFrame(doorTile, 0)
end

local function SteamHiss(Fn)
	local function Steam(x, vx)
		return effects.Smoke(vector.Add(tPos, { x = x, y = 128 }),
				     { gravity = { x = vx, y = 50 },
				       disableProximitySensor = true,
				       vel = {x = 0, y = -100},
				       interval = 0.05,
				       life = 1.5,
				       z = -3, })
	end
	local s = { Steam(224, 100), Steam(96, -100), Steam(160, 0) }
	for i = 1, 3, 1 do s[i].Kick() end
	local function Stop()
		for i = 1, 3, 1 do s[i].Stop() end
		eapi.AddTimer(staticBody, 1.5, Fn)
	end
	eapi.AddTimer(staticBody, 2, Stop)
	eapi.PlaySound(gameWorld, "sound/steam.ogg")
end

local function Use(level, pos, flip)
	mainPC.StopInput()
	teleporter.CloseDoor()
	local function TeleportCallback()
		util.Message = "teleport"
		util.GoToAndPlace(level, mainPC, pos, flip)
	end
	local function Flash()
		effects.Fade(0.0, 1.0, 1.0, TeleportCallback, nil, 120, 'h')
	end
	eapi.AddTimer(gameWorld, 2, function() SteamHiss(Flash) end)
end

local function Arrive()
	if util.Message == "teleport" then
		util.Message = nil
		mainPC.StopInput()
		DoorShut()
		
		local function Open()
			eapi.AddTimer(gameWorld, 1.5, mainPC.StartInput)
			OpenDoor()
		end
		local Arival = function() SteamHiss(Open) end
		effects.Fade(1.0, 0.0, 1.0, Arival, nil, 120, 'h')
	end
end

teleporter = {
	Put = Put,
	OpenDoor = OpenDoor,
	CloseDoor = CloseDoor,
	DoorShut = DoorShut,
	Arrive = Arrive,
	Use = Use,
}
return teleporter
