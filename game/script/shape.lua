-- all the walls and ground must be created with these functions
-- hopefully this will serve as some kind of abstraction

local thickness = 10

local function Sign(x)
	if (x > 0) then
		return 1
	elseif (x < 0) then
		return -1
	else
		return 0
	end
end

local function GetShapeType(pos1, pos2)
	if (pos1.y == pos2.y) then
		return 'Box'
	elseif (pos1.x == pos2.x) then
		return 'Box'
	elseif (Sign(pos1.x - pos2.x) == Sign(pos1.y - pos2.y)) then
		return 'LeftSlope'
	else 
		return 'RightSlope'
	end
end

local function Line(pos1, pos2, a, t, body)
	local bb = {}
	
	if not pos1.x then
		pos1 = {x=pos1[1], y=pos1[2]}
		pos2 = {x=pos2[1], y=pos2[2]}
	end
	
	t = t or 2
	a = a or GetShapeType(pos1, pos2)
	body = body or staticBody
	
	bb.l = math.floor(math.min(pos1.x, pos2.x))
	bb.r = math.floor(math.max(pos1.x, pos2.x))
	bb.b = math.floor(math.min(pos1.y, pos2.y))
	bb.t = math.floor(math.max(pos1.y, pos2.y))
	
	if bb.l == bb.r then
		bb.l = bb.l - t
	end
	if bb.b == bb.t then
		bb.b = bb.b - t
	end
	
	return eapi.NewShape(body, nil, bb, a)
end

shape = {
	Line = Line,
}
return shape
