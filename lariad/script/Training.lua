dofile("script/action.lua")
dofile("script/occlusion.lua")
dofile("script/exit.lua")
dofile("script/wood.lua")
dofile("script/Common.lua")
dofile("script/save-point.lua")

LoadPlayers()
camera = util.CreateCamera(gameWorld)
eapi.SetBackgroundColor(gameWorld, {r=0.0,g=0.0,b=0.0})
staticBody = eapi.GetStaticBody(gameWorld)
eapi.RandomSeed(42)

local stage = game.GetState().trainingLevel

local function PositionText(xRatio, yOffset)
	return function(totalSize, boxSize, axis)
		local width = totalSize - boxSize
		return (axis == "x") and (width * xRatio) or yOffset
	end
end

local TrainingMsgLoc = { 
	PositionText(0.50, 64),
	PositionText(0.25, 64),
	PositionText(0.80, 48),
	PositionText(0.50, 64),
	PositionText(0.50, 62),
	PositionText(0.50, 64),
}

util.DialogBox(txt.trainingText[stage], camera, TrainingMsgLoc[stage])

local function ChangeRoom(pos)
	game.GetState().trainingLevel = stage + 1
	if stage == 5 then
		game.GetState().hasSterling = true
		game.GetState().weaponInUse = "image/sterling.png"		
	end
	if stage == 6 then
		util.GoTo("Startup", nil, true)
	else
		local effect = eapi.SLIDE_RIGHT
		util.GoToAndPlace("Training", mainPC, pos, false, effect)
	end
end

local function TrainingExit(bb, pos)
	local function ChangeRoomPos() ChangeRoom(pos) end
	action.MakeActivator(bb, ChangeRoomPos, nil, staticBody, true)
end

local function Blackness(bb)
	local w = bb.r - bb.l
	local h = bb.t - bb.b
	Occlusion.put('f', bb.l, bb.b, 0.5, { size = { w, h } }, staticBody)
end

local exports = {
	TrainingExit = {func=TrainingExit,points=2},
	Blackness = {func=Blackness,points=2},
	FrontLog = {func=wood.Log(0.9),points=1},
	BackLog = {func=wood.Log(-1.5),points=1},
	Plank = {func=wood.Plank,points=2},
	WallPlank = {func=wood.WallPlank,points=1},
	SavePoint = {func=savePoint.Put,points=1},
	Blocker = {func=common.Blocker,points=2},
	FrontPlank = {func=wood.FrontPlank,points=2},
	HealthPlus = {func=destroyer.HealthPlus(7),points=1},
	MedKit2 = {func=savePoint.Medkit2,points=1},
}

editor.Parse("script/Training-"..stage..".lua", gameWorld, exports)
