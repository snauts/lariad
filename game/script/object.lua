local function SetVel(object, vel)
	if object.vel then
		object.vel = vel
	elseif object.body then
		eapi.SetVel(object.body, vel)
	end
end

local function SetVelX(object, x)
	if object.vel then
		object.vel.x = x
	elseif object.body then
		eapi.SetVelX(object.body, x)
	end
end

local function SetVelY(object, y)
	if object.vel then
		object.vel.y = y
	elseif object.body then
		eapi.SetVelY(object.body, y)
	end
end

local function GetVel(object)
	if object.vel then
		return object.vel
	elseif object.body then
		return eapi.GetVel(object.body)
	else
		return vector.null
	end
end

local function Collide(player)
	if player.Collide then player.Collide(player) end
end

local function Box(world, playerShape, boxShape, resolve)
	local player = eapi.pointerMap[playerShape]
	local pos = eapi.GetPos(player.body)
	local deltaPos = eapi.GetDeltaPos(player.body)
	
	playerShape = eapi.GetData(playerShape).shape
	boxShape = eapi.GetData(boxShape).shape
	
	if playerShape.t - deltaPos.y <= boxShape.b and
		    resolve.r ~= 0 and resolve.l ~= 0 then
		-- In previous step we were below the box shape.
		eapi.SetPos(player.body, {pos.x, pos.y+resolve.b})
		if not(player.ignoreObstacle) then SetVelY(player, 0) end
		player.jumpInProgress = false
		player.contact.ceiling = true
	elseif playerShape.b - deltaPos.y >= boxShape.t and
		    resolve.r ~= 0 and resolve.l ~= 0 then
		-- In previous step we were above the box shape.
		eapi.SetPos(player.body, {pos.x, pos.y+resolve.t})
		player.CollisionFixup()
		player.jumpInProgress = false
		player.contact.ground = true
	elseif playerShape.r - deltaPos.x <= boxShape.l and
		    resolve.b ~= 0 and resolve.t ~= 0 then
		-- In previous step we were to the left the box shape.
		eapi.SetPos(player.body, {pos.x+resolve.l, pos.y})
		if not(player.ignoreObstacle) then SetVelX(player, 0) end
		player.contact.right = true
	elseif playerShape.l - deltaPos.x >= boxShape.r and
		    resolve.b ~= 0 and resolve.t ~= 0 then
		-- In previous step we were to the right the box shape.
		eapi.SetPos(player.body, {pos.x+resolve.r, pos.y})
		if not(player.ignoreObstacle) then SetVelX(player, 0) end
		player.contact.left = true
	else
		-- Find the direction whith least resolution distance.
		local left = math.abs(resolve.l)
		local right = math.abs(resolve.r)
		local bottom = math.abs(resolve.b)
		local top = math.abs(resolve.t)
		local edges = {
			{math.abs(resolve.l), {pos.x+resolve.l, pos.y}},
			{math.abs(resolve.r), {pos.x+resolve.r, pos.y}},
			{math.abs(resolve.b), {pos.x, pos.y+resolve.b}},
			{math.abs(resolve.t), {pos.x, pos.y+resolve.t}}
		}
		table.sort(edges, function(a,b) return a[1] < b[1] end)
		
		-- Resolve collision and leave it at that.
		eapi.SetPos(player.body, edges[1][2])
	end

	Collide(player)
end

local function OneWayGround(world, playerShape, groundShape, resolve)
	local player = eapi.pointerMap[playerShape]
	local pos = eapi.GetPos(player.body)
	local deltaPos = eapi.GetDeltaPos(player.body)
	local contact = false
	
	-- If previously player was above the shape, resolve the collision.
	-- Otherwise, ignore.
	local gshape = eapi.GetData(groundShape).shape
	local pshape = eapi.GetData(playerShape).shape
	if pshape.b - deltaPos.y >= gshape.t then
		-- See if we're jumping downward through the one way shape.
		if player.downJump then
			-- Subtract one unit from Y coordinate, so that we don't
			-- end up here again due to low gravity.
			eapi.SetPos(player.body, {pos.x, pos.y-1})
			player.downJump = false
			contact = false
		else
			contact = true
		end
	end
	
	if contact then
		eapi.SetPos(player.body, {pos.x, pos.y+resolve.t})
		player.CollisionFixup()
		player.jumpInProgress = false
		player.contact.ground = true
		player.contact.onewayGround = groundShape
		Collide(player)
	end
end

local function RightSlope(world, playerShape, slopeShape, resolve)
	-- RightSlope collision function handles these slopes:
	--   |\
	--   | \     "Right slope" because objects would slide to the right if
	--   |__\    dropped onto such a slope.
	local player = eapi.pointerMap[playerShape]
	local pos = eapi.GetPos(player.body)
	local deltaPos = eapi.GetDeltaPos(player.body)
	local contact = false
	
	playerShape = eapi.GetData(playerShape).shape
	slopeShape = eapi.GetData(slopeShape).shape
	
	-- Slope width & height.
	slopeShape.w = slopeShape.r - slopeShape.l
	slopeShape.h = slopeShape.t - slopeShape.b
	
	if playerShape.l - deltaPos.x >= slopeShape.r and
		    playerShape.b < slopeShape.b and
		    player.prevContact and
		    not player.prevContact.rightSlope then
		-- In previous step we were to the right the slope shape, and
		-- now we're running into the bottom of the slope but not *onto*
		-- the slope.
		eapi.SetPos(player.body, {pos.x+resolve.r, pos.y})
		if GetVel(player).x < 0 and not(player.ignoreObstacle) then
			SetVelX(player, 0)
		end
		player.contact.left = true
		return
	end
	
	if playerShape.l <= slopeShape.l then
		-- Player is on top of slope summit.
		local up = slopeShape.t - playerShape.b
		eapi.SetPos(player.body, {x=pos.x, y=pos.y+up})
		contact = true
	else
		local diff = playerShape.l - slopeShape.l
		local w = slopeShape.w
		local h = slopeShape.h
		local touchPoint = {
			x=playerShape.l,
			y=slopeShape.b + h - math.floor(h*diff/w)
		}
		if playerShape.b <= touchPoint.y then
			-- Player is into lower part of slope.
			local up = touchPoint.y - playerShape.b
			eapi.SetPos(player.body, {x=pos.x, y=pos.y+up})
			contact = true
		elseif GetVel(player).y <= 0
			and player.prevContact 
			and player.prevContact.rightSlope
			and not player.contact.leftSlope then
			-- Player is above slope, but should be moved downward.
			local down = playerShape.b - touchPoint.y
			eapi.SetPos(player.body, {x=pos.x, y=pos.y-down})
			contact = true
		end
	end
	
	if contact then
		player.CollisionFixup()
		player.jumpInProgress = false
		player.contact.ground = true
		player.contact.rightSlope = slopeShape
		Collide(player)
	end
end

local function LeftSlope(world, playerShape, slopeShape, resolve)
	-- LeftSlope collision function handles these slopes:
	--      /|
	--     / |    "Left slope" because objects would slide to the left if
	--    /__|    dropped onto such a slope.
	local player = eapi.pointerMap[playerShape]
	local pos = eapi.GetPos(player.body)
	local deltaPos = eapi.GetDeltaPos(player.body)
	local contact = false
	
	playerShape = eapi.GetData(playerShape).shape
	slopeShape = eapi.GetData(slopeShape).shape
	
	-- Slope width & height.
	slopeShape.w = slopeShape.r - slopeShape.l
	slopeShape.h = slopeShape.t - slopeShape.b
	
	if playerShape.r - deltaPos.x <= slopeShape.l and
		    playerShape.b < slopeShape.b and
		    player.prevContact and
		    not player.prevContact.leftSlope then
		-- In previous step we were to the left the slope shape, and now
		-- we're running into the bottom of the slope but not *onto* the
		-- slope.
		eapi.SetPos(player.body, {pos.x+resolve.l, pos.y})
		if GetVel(player).x > 0 and not(player.ignoreObstacle) then
			SetVelX(player, 0)
		end
		player.contact.right = true
		return
	end
	
	if playerShape.r >= slopeShape.r then
		-- Player is on top of slope summit.
		local up = slopeShape.t - playerShape.b
		eapi.SetPos(player.body, {x=pos.x, y=pos.y+up})
		contact = true
	else
		local diff = playerShape.r - slopeShape.l
		local w = slopeShape.w
		local h = slopeShape.h
		local touchPoint = {
			x=playerShape.r,
			y=slopeShape.b + math.floor(h*diff/w)
		}
		if playerShape.b <= touchPoint.y then
			-- Player is into lower part of slope.
			local up = touchPoint.y - playerShape.b
			eapi.SetPos(player.body, {x=pos.x, y=pos.y+up})
			contact = true
		elseif GetVel(player).y <= 0
			and player.prevContact
			and player.prevContact.leftSlope
			and not player.contact.rightSlope then
			-- Player is above slope, but should be moved downward.
			local down = playerShape.b - touchPoint.y
			eapi.SetPos(player.body, {x=pos.x, y=pos.y-down})
			contact = true
		end
	end
	
	if contact then
		player.CollisionFixup()
		player.jumpInProgress = false
		player.contact.ground = true
		player.contact.leftSlope = slopeShape
		Collide(player)
	end
end

local function CeilingRightSlope(world, playerShape, slopeShape, resolve)
	-- CeilingRightSlope collision function handles these slopes:
	--    ___
	--   |  /   "Right slope" because objects would slide to the right if
	--   | /    pushed upward onto such a slope.
	--   |/
	local player = eapi.pointerMap[playerShape]
	local pos = eapi.GetPos(player.body)
	local contact = false
	
	playerShape = eapi.GetData(playerShape).shape
	slopeShape = eapi.GetData(slopeShape).shape
	
	-- Slope width & height.
	slopeShape.w = slopeShape.r - slopeShape.l
	slopeShape.h = slopeShape.t - slopeShape.b
	
	if playerShape.l <= slopeShape.l then
		-- Player is on top of slope summit.
		local down = playerShape.t - slopeShape.b
		eapi.SetPos(player.body, {x=pos.x, y=pos.y-down})
		if not(player.ignoreObstacle) then SetVelY(player, 0) end
		contact = true
	else
		local diff = playerShape.l - slopeShape.l
		local w = slopeShape.w
		local h = slopeShape.h
		local touchPoint = {
			x=playerShape.l,
			y=slopeShape.b + math.floor(h*diff/w)
		}
		if playerShape.t >= slopeShape.t then
			eapi.SetPos(player.body, {x=pos.x+resolve.r, y=pos.y})
			player.contact.left = true
			return
		end
		if playerShape.t >= touchPoint.y then
			-- Player is into upper part of slope.
			local down = playerShape.t - touchPoint.y
			eapi.SetPos(player.body, {x=pos.x, y=pos.y-down})
			if not(player.ignoreObstacle) then 
				SetVelX(player, 100 * down * w / h)
			end
			contact = true
		end
	end
	
	if contact then
		player.jumpInProgress = false
		player.contact.ceiling = true
		Collide(player)
	end
end

local function CeilingLeftSlope(world, playerShape, slopeShape, resolve)
	-- CeilingLeftSlope collision function handles these slopes:
	--    __
	--   \  |  "Left slope" because objects would slide to the left if pushed
	--    \ |  upward onto such a slope.
	--     \|
	local player = eapi.pointerMap[playerShape]
	local pos = eapi.GetPos(player.body)
	local contact = false
	
	playerShape = eapi.GetData(playerShape).shape
	slopeShape = eapi.GetData(slopeShape).shape
	
	-- Slope width & height.
	slopeShape.w = slopeShape.r - slopeShape.l
	slopeShape.h = slopeShape.t - slopeShape.b
	
	if playerShape.r >= slopeShape.r then
		-- Player is on top of slope summit.
		local down = playerShape.t - slopeShape.b
		eapi.SetPos(player.body, {x=pos.x, y=pos.y-down})
		if not(player.ignoreObstacle) then SetVelY(player, 0) end
		contact = true
	else
		local diff = slopeShape.r - playerShape.r
		local w = slopeShape.w
		local h = slopeShape.h
		local touchPoint = {
			x=playerShape.r,
			y=slopeShape.b + math.floor(h*diff/w)
		}
		if playerShape.t >= slopeShape.t then
			eapi.SetPos(player.body, {x=pos.x+resolve.l, y=pos.y})
			player.contact.right = true
			return
		end
		if playerShape.t >= touchPoint.y then
			-- Player is into upper part of slope.
			local down = playerShape.t - touchPoint.y
			eapi.SetPos(player.body, {x=pos.x, y=pos.y-down})
			if not(player.ignoreObstacle) then 
				SetVelX(player, -100 * down * w / h)
			end
			contact = true
		end
	end
	
	if contact then
		player.jumpInProgress = false
		player.contact.ceiling = true
		Collide(player)
	end
end

local function Platform(world, playerShape, groundShape, resolve)
	local player = eapi.pointerMap[playerShape]
	local platform = eapi.pointerMap[groundShape]
	local pos = eapi.GetPos(player.body)
	local deltaPosPlayer = eapi.GetDeltaPos(player.body)
	local deltaPosGround = eapi.GetDeltaPos(platform.body)
	local contact = false
	world = eapi.GetData(world)
	
	-- If previously player was above the shape, resolve the collision.
	-- Otherwise, ignore.
	local gshape = eapi.GetData(groundShape).shape
	local pshape = eapi.GetData(playerShape).shape
	if pshape.b - deltaPosPlayer.y >= gshape.t - deltaPosGround.y then
		-- See if we're jumping downward through the one way shape.
		if not(platform.downJumpDisabled) and player.downJump then
			-- Subtract from Y coordinate the distance platform
			-- moves downward in one step + one unit, so that we
			-- don't end up here again due to low gravity.
			-- take abs because platform may move up or down
			local py = GetVel(platform).y
			local down = math.abs(py) * world.stepSec
			eapi.SetPos(player.body, {pos.x, pos.y - down - 1})
			player.downJump = false
			contact = false
			eapi.Unlink(player.body)
			
			-- need this if platform is moving downward fast
			if not(player.ignoreObstacle) then 
				SetVelY(player, py)
			end
		else
			eapi.Link(player.body, platform.body)
			contact = true
		end
	end
	
	if contact then
		eapi.SetPos(player.body, {pos.x, pos.y+resolve.t})
		player.CollisionFixup()
		player.jumpInProgress = false
		player.contact.ground = true
		player.contact.onewayGround = groundShape
		player.contact.platform = platform
		Collide(player)
	end
--[[
	if contact then
		local player = eapi.pointerMap[playerShape]
		local platform = eapi.pointerMap[groundShape]
		player.platform = platform
	end]]--
end

local function RegisterHandlers(name, priority)
	priority = priority or 100
	eapi.Collide(gameWorld, name, "Box", Box, priority)
	eapi.Collide(gameWorld, name, "Platform", Platform, priority)
	eapi.Collide(gameWorld, name, "PondBottom", Box, priority - 1)
	eapi.Collide(gameWorld, name, "OneWayGround", OneWayGround, priority)
	eapi.Collide(gameWorld, name, "LeftSlope", LeftSlope, priority + 10)
	eapi.Collide(gameWorld, name, "RightSlope", RightSlope, priority + 10)

	eapi.Collide(gameWorld, name, "CeilingLeftSlope",
		     CeilingLeftSlope, priority)
	eapi.Collide(gameWorld, name, "CeilingRightSlope",
		     CeilingRightSlope, priority)
end

local function DampVelocity(object, damp)
	object.CollisionFixup = function() 
		if object.Ground then object.Ground(object) end
		SetVel(object, { x = GetVel(object).x * damp, y = 0 })
	end
	object.contact = { }
end

local function CompleteHalt(object)
	DampVelocity(object, 0)
end

local function VerticalHalt(object)
	DampVelocity(object, 1)
end

local function DoNotHalt(object)
	object.CollisionFixup = function() end	
	object.contact = { }
end

local function SimpleStep(obj)
	local function Step(world)
		local worldData = eapi.GetData(world)
		local stepSec = worldData.stepSec
		
		local pos = eapi.GetPos(obj.body)
		
		-- Apply gravity to velocity.
		local impulse = vector.Scale(obj.gravity, stepSec)
		obj.vel = vector.Add(obj.vel, impulse)
		
		-- Update obj position.
		local delta = vector.Scale(obj.vel, stepSec)
		local newPos = vector.Add(pos, delta)
		eapi.SetPos(obj.body, newPos)
		
		-- Save and reset contact state.
		obj.prevContact = obj.contact
		obj.contact = { }
	end
	eapi.SetStepFunc(obj.body, Step, nil)
	obj.hasStepFunc = true
end

local function Delete(obj)
	if obj.hasStepFunc then
		eapi.SetStepFunc(obj.body, nil, nil)
		obj.hasStepFunc = false
	end
	if obj.shapeObj then
		eapi.pointerMap[obj.shapeObj] = nil
	end
	eapi.Destroy(obj.body)
	obj.shapeObj = nil
	obj.body = nil
end

object = {
	Box = Box,
	OneWayGround = OneWayGround,
	LeftSlope = LeftSlope,
	RightSlope = RightSlope,
	
	Delete = Delete,
	DoNotHalt = DoNotHalt,
	SimpleStep = SimpleStep,
	CompleteHalt = CompleteHalt,
	VerticalHalt = VerticalHalt,
	DampVelocity = DampVelocity,
	RegisterHandlers = RegisterHandlers,

	SetVel = SetVel,
	GetVel = GetVel,
	SetVelX = SetVelX,
	SetVelY = SetVelY,
}
return object
