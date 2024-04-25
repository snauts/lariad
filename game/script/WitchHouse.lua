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

eapi.PlaySound(gameWorld, "sound/frogs.ogg", -1, 0.1)

local treeTexture = { "image/trees.png", filter = true }
swampBG = eapi.NewSpriteList(treeTexture, { { 0, 412 }, { 100, 80 } })

local function Background(bb)
	local pos = { x = bb.l, y = bb.b }
	local size = { x = bb.r - bb.l, y = bb.t - bb.b }
	eapi.NewTile(staticBody, pos, size, swampBG, -20)
end

Occlusion.put('f', -400, 80, 10, { size = { 800, 256 } }, staticBody)
Occlusion.put('f', -400, -240, 10, { size = { 119, 400 } }, staticBody)
common.Gradient(-400, -48,  800, 128, false, false, Occlusion.gradient)

local function BonesInfo(bb)
	action.MakeMessage(txt.bones, bb, txt.bonesInfo)
end

local function Exit(bb)
	ExitRoom(bb, "swamp-map", {11400, 284},
		 nil, nil, nil, eapi.SLIDE_RIGHT)
end

local exports = {
	Skull = {func=common.Skull,points=1},
	RibCage = {func=common.RibCage,points=1},
	BloodyHandPrint = {func=common.BloodyHandPrint,points=1},
	FrontLog = {func=wood.Log(0.9),points=1},
	BackLog = {func=wood.Log(-1.5),points=1},
	Plank = {func=wood.Plank,points=2},
	WallPlank = {func=wood.WallPlank,points=1},
	SavePoint = {func=savePoint.Put,points=1},
	Background = {func=Background,points=2},
	BonesInfo = {func=BonesInfo,points=2},
	Blocker = {func=common.Blocker,points=2},
	Exit = {func=Exit,points=2},
	Tutorial = {func=proximity.Tutorial,points=2},
}
editor.Parse("script/WitchHouse-edit.lua", gameWorld, exports)
util.ContinueMusic("sound/morning.ogg", 0.5)
