local allProximities = { }

local bufferZone = { x = 64, y = 128 } -- player size
local zoneSize = 64

local function TriggerHandler(world, playerShape, proximityShape, resolve)
	local proximity = allProximities[proximityShape]
	proximity.CreateUntrigger()
	proximity.Trigger(proximity.cookie)
end

local function UntriggerHandler(world, playerShape, proximityShape, resolve)
	local proximity = allProximities[proximityShape]
	proximity.CreateTrigger()
	proximity.Untrigger(proximity.cookie)
end

local function Create(Trigger, Untrigger, cookie, shape, body)
	local shapeObj = nil
	local shapeTbl = { }
	local proximity = { }
	body = body or staticBody
	if type(shape) == "number" then
		shape = { l = -shape, r = shape, b = -shape, t = shape }
	end
	proximity.Delete = function()
		if shapeObj then
			allProximities[shapeObj] = nil
			eapi.Destroy(shapeObj)
			shapeObj = nil
		end

		for i, s in ipairs(shapeTbl) do
			if s then eapi.Destroy(s) end
			allProximities[s] = nil
		end
		shapeTbl = { }
	end
	proximity.CreateTrigger = function()
		proximity.Delete()
		shapeObj = eapi.NewShape(body, nil, shape, "Trigger")
		allProximities[shapeObj] = proximity
	end
	local function CreateUntiggerShape(i, shape)
		shapeTbl[i] = eapi.NewShape(body, nil, shape, "Untrigger")
		allProximities[shapeTbl[i]] = proximity
	end
	local function CreateOuterShape(dst, src, sign)
		local outerShape = {
			l = shape.l - bufferZone.x - zoneSize,
			r = shape.r + bufferZone.x + zoneSize, 
			b = shape.b - bufferZone.y - zoneSize,
			t = shape.t + bufferZone.y + zoneSize,
		}
		outerShape[dst] = outerShape[src] + sign * zoneSize
		return outerShape
	end
	proximity.CreateUntrigger = function()
		proximity.Delete()
		CreateUntiggerShape(1, CreateOuterShape("r", "l",  1))
		CreateUntiggerShape(2, CreateOuterShape("l", "r", -1))
		CreateUntiggerShape(3, CreateOuterShape("t", "b",  1))
		CreateUntiggerShape(4, CreateOuterShape("b", "t", -1))
	end
	proximity.cookie = cookie
	proximity.Trigger = Trigger
	proximity.Untrigger = Untrigger
	proximity.CreateTrigger()
	return proximity
end

eapi.Collide(gameWorld, "Player", "Trigger", TriggerHandler, 50)
eapi.Collide(gameWorld, "Player", "Untrigger", UntriggerHandler, 50)

local function TutorialPos(totalSize, boxSize, axis)
	local width = totalSize - boxSize
	return (axis == "x") and (width * 0.5) or (totalSize - boxSize)
end	

local function Tutorial(bb, num)
	local tiles = nil
	if game.GetState().startLives == 1 then
		return function() end
	end
	local function ShowText()
		if game.GetState().tutorial[num] and num == 1 then return end
		game.GetState().tutorial[num] = true
		local info = txt.inGameTraining[num]
		tiles = util.DialogBox(info, camera, TutorialPos)
	end
	local function HideText()
		if tiles then
			util.Map(eapi.Destroy, tiles)
			tiles = nil
		end
	end
	Create(ShowText, HideText, nil, bb)
	return HideText
end

proximity = {
	Create = Create,
	Tutorial = Tutorial,
}
return proximity
