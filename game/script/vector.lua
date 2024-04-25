
--[[ 2D vector manipulation routines. ]]--

--[[ Add two vectors and return the result. ]]--
local function Add(a, b)
	return {x=a.x + b.x, y=a.y + b.y}
end

--[[ Subtract two vectors. ]]--
local function Sub(a, b)
	return {x=a.x-b.x, y=a.y-b.y}
end

--[[ Multiply vector by a number. ]]--
local function Scale(v, f)
	return {x=v.x*f, y=v.y*f}
end

--[[ Reverse vector. ]]--
local function Reverse(v)
	return {x=-v.x, y=-v.y}
end

local function Length(v)
	return math.sqrt(v.x * v.x + v.y * v.y)
end

local function Distance(a, b)
	return Length(Sub(a, b))
end

local function Normalize(v, amount)
	amount = amount or 1.0
	local len = Length(v)
	if len == 0 then
		return v
	else
		return Scale(v, amount / len)
	end
end

local function Round(v, idp)
	local mult = 10^(idp or 0)
	return {x=math.floor(v.x * mult + 0.5) / mult,
		y=math.floor(v.y * mult + 0.5) / mult}
end

--[[ Return true if both coordinates of v are zero, false otherwise. ]]--
local function IsZero(v)
	return (v.x == 0 and v.y == 0)
end

local function Check(v)
	return type(v) == "table" and v.x and v.y
end

local function Offset(v, x, y)
	return { x = v.x + x, y = v.y + y }
end

local function ToRadians(theta)
	return theta * (math.pi / 180)
end

local function Rotate(v, theta)
	theta = ToRadians(theta)
	local cs = math.cos(theta)
	local sn = math.sin(theta)
	return { x = v.x * cs - v.y * sn,
		 y = v.x * sn + v.y * cs }
end

local function Floor(p)
	return { x = math.floor(p.x), y = math.floor(p.y) }
end

local null = { x = 0, y = 0 }

vector = {
	Add=Add,
	Sub=Sub,
	Floor = Floor,
	Scale=Scale,
	Reverse=Reverse,
	Round=Round,
	Length=Length,
	Distance=Distance,
	Normalize=Normalize,
	ToRadians=ToRadians,
	Check=Check,
	Offset=Offset,
	Rotate=Rotate,
	null = null,
}
return vector
