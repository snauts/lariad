util.msg = "Outro"

game.GetState().playerHidden = true
dofile("script/swamp-map.lua")

local trackBody = eapi.NewBody(gameWorld, { x = 2950, y = 900 })
util.CameraTracking.call(trackBody)

local function BackToMenu()
	util.GoTo("Startup", nil, true)
end

local function DelayBackToMenu()
	eapi.AddTimer(staticBody, 2.0, BackToMenu)
end

local function EndMessage()
	util.GameMessage(txt.theEnd, camera, DelayBackToMenu)
	eapi.AddTimer(staticBody, 3.0, util.MessageDone)
end

local function TheEnd()
	eapi.AddTimer(staticBody, 2.0, EndMessage)
end

local tiles = { }

local function FadeOut()
	effects.Fade(0.0, 1.0, 2.0, TheEnd, nil, 50)	
	util.Map(eapi.Destroy, tiles)
end

local function Credits()
	util.MaxWidth(txt.credits)
	local pos = { x = 0, y = 0 }
	local body = eapi.NewBody(gameWorld, { x = 3175, y = 600 })
	eapi.SetVel(trackBody, { x = 0, y = -30})
	tiles = util.CreateViewportLines(txt.credits, body, pos)
	eapi.SetVel(body, { x = 0, y = 20 })
	eapi.AddTimer(staticBody, 30.0, FadeOut)
end

local function Start()
	eapi.SetPos(mainPC.body, { x = 2700, y = 200 })
	eapi.AddTimer(staticBody, 5.0, Credits)
end

effects.Fade(1.0, 0.0, 3.0, Start, nil, 50)	

common.Fire({ x = 2688, y = 48})
common.GullTurnHead({x=2717,y=1006},2,true,3)
common.GullTurnHead({x=2997,y=1006},2)
wood.SittingGull({x=2751,y=978})

local pImg = eapi.NewSpriteList("image/wood.png", {{256, 192}, {128, 128}})
local hImg = eapi.TextureToSpriteList("image/player-hand.png", {64, 128})

local bottleFileName = { "image/wood.png", filter = true }
local bottleImg = eapi.NewSpriteList(bottleFileName, {{193, 33}, {30, 30}})

local function PlayerWithBeer(pos)
	eapi.NewTile(staticBody, vector.Offset(pos, -36, 8), nil, pImg, 0)
	eapi.SetFrame(eapi.NewTile(staticBody, pos, nil, hImg, 0.1), 8)
	
	local offset = { x = -16, y = -16 }
	local bottleBody = eapi.NewBody(gameWorld, vector.Offset(pos, 40, 48))
	local tile = eapi.NewTile(bottleBody, offset, nil, bottleImg, 0.05)
	eapi.SetAttributes(tile, { angle = vector.ToRadians(-30) })
end

PlayerWithBeer({x = 3052, y = 803})

wood.Roast({x=2662,y=95})
wood.RoastBar({x=2643,y=104},1.1)
wood.RoastBar({x=2705,y=104})
wood.RoastHolder({x=2620,y=8})
wood.RoastHolder({x=2729,y=8})
