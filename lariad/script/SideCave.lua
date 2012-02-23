dofile("script/exit.lua")
dofile("script/occlusion.lua")
dofile("script/Cave.lua")
dofile("script/action.lua")
dofile("script/shape.lua")

LoadPlayers()
local camBox = {l=-350,r=450,b=-200,t=900}
camera = util.CreateCamera(gameWorld, mainPC, camBox)
eapi.SetBackgroundColor(gameWorld, {r=0.0, g=0.0, b=0.0})

eapi.RandomSeed(42)

staticBody = eapi.GetStaticBody(gameWorld)

local tileMap = {
   "stttstststtsts",
   "tttssstHIJHsts",
   "stssts6    7st",
   "tttssu     rts",
   "sssttC  accsts",
   "tststu  itstst",
   "ststsm  qsttss",
   "tssIJK  isstst",
   "tt6     qtstss",
   "tsX     qststt",
   "ssscde  iststt",
   "tttssu  itstss",
   "tsstsC  qststs",
   "sststC  GIJtss",
   "ststsm     7st",
   "tststm     rts",
   "ststsC  adbtss",
   "stttstbbststst",
   "tsststssststss",
}

util.CreateTiles(staticBody, tileMap,  rock, {x=-400,y=-240}, nil, 1)

staticBody = eapi.GetStaticBody(gameWorld)

for i = -5, 6, 1 do
	for j = -3, 14, 1 do
		DarkRock(RandomElement({'s', 't'}), i * 64, j * 64, -1.0)
	end
end

local function Plank(x, y)
	util.PutTile(staticBody, 'c', bamboo, {x,  y}, -0.1)
	shape.Line({x + 16, y + 40}, {x + 48, y + 40}, "OneWayGround")
end

Plank(84, -96)
Plank(-40, 0)
Plank(72, 96)
Plank(-40, 192)
Plank(72, 384)
Plank(-40, 480)
Plank(72, 576)

Occlusion.passage(200, 775, -0.1, "Waterfall",
		  {-6845,-1139}, txt.exit, eapi.ZOOM_IN)

Occlusion.passage(200, 8,   -0.1, "Waterfall", 
		  {-6845,-3380}, txt.exit, eapi.ZOOM_IN)

for i = -7, 7, 1 do
	Occlusion.put('c', i * 64, 912, 10)
	Occlusion.put('c', i * 64, -240, 10, { flip = { false, true } })
end

for i = -4, 15, 1 do
	Occlusion.put('a', 432, i * 64, 10)
	Occlusion.put('b', -400, i * 64, 10)
end

DecoratorField(-400, -240, 240, 440, 64)
DecoratorField(-400,  460, 240, 360, 64)

DecoratorField( 120,   80, 240, 500, 128)

DecoratorField( 120, -240, 240,  60, 32)
DecoratorField(-160,  845, 520,   0, 32)


shape.Line({-239.00, 480.00},{-80.00, 480.00}, "Box", 10)
shape.Line({-80.00, 470.00},{-35.00, 533.00}, "CeilingRightSlope")
shape.Line({-30.00, 533.00},{-30.00, 818.00}, "Box", 10)
shape.Line({-35.00, 818.00},{19.00, 864.00}, "CeilingRightSlope")
shape.Line({19.00, 864.00},{346.00, 864.00}, "Box")
shape.Line({346.00, 864.00},{372.00, 829.00}, "CeilingLeftSlope")
shape.Line({372.00, 829.00},{372.00, 743.00}, "Box", 10)
shape.Line({379.00, 743.00},{344.00, 715.00})
shape.Line({344.00, 715.00},{172.00, 715.00})
shape.Line({172.00, 715.00},{130.00, 676.00})
shape.Line({139.00, 676.00},{139.00, 139.00}, "Box", 12)
shape.Line({140.00, 139.00},{181.00, 97.00}, "CeilingLeftSlope")
shape.Line({181.00, 95.00},{360.00, 95.00}, "Box", 10)
shape.Line({360.00, 88.00},{374.00, 56.00}, "CeilingLeftSlope")
shape.Line({374.00, 56.00},{379.00, -42.00}, "Box")
shape.Line({379.00, -42.00},{323.00, -50.00})
shape.Line({323.00, -50.00},{170.00, -50.00}, "LeftSlope")
shape.Line({130.00, -86.00},{170.00, -52.00})
shape.Line({130.00, -86.00},{130.00, -128.00}, "Box", 10)
shape.Line({125.00, -128.00},{-35.00, -128.00})
shape.Line({-35.00, -128.00},{-35.00, 320.00}, "Box", 10)
shape.Line({-37.00, 320.00},{-72.00, 335.0})
shape.Line({-72.00, 335.0},{-237.00, 335.0})
shape.Line({-237.00, 335.0},{-281.00, 358.00})
shape.Line({-281.00, 358.00},{-281.00, 437.00}, "Box", 10)
shape.Line({-281.00, 437.00},{-239.00, 471.00}, "CeilingRightSlope")

cave.PutSpike({x = -16, y = -128})
cave.PutSpike({x = 48, y = -128})

local gisaku = eapi.TextureToSpriteList("image/gisaku.png", {128, 128})
eapi.Animate(eapi.NewTile(staticBody, {-250,  320}, nil, gisaku, -0.05),
	     eapi.ANIM_LOOP,
	     8)

eapi.PlaySound(gameWorld, "sound/waterfall.ogg", -1, 0.1)

action.MakeMessage(txt.gisaku, {l=-195, b=340, r=-175, t=360}, txt.gisakuTalk)
