local img = eapi.TextureToSpriteList("image/save-point.png", {64, 128})

local function SaveGame(Continue)
	local function Noop() end
	local function Stop()
		util.MessageDone()
		Continue()
	end
	if game.GetState().currentRoom == "Training"  then
		util.GameMessage(txt.thisIsJustATest, camera, Stop)
		return true
	end
	eapi.PlaySound(gameWorld, "sound/modem.ogg", 0, 0.3)
	util.GameMessage(txt.saveGameUpload, camera, Noop)
	eapi.AddTimer(gameWorld, 4.7, Stop)
	game.Save(nil, true)
	return true
end

local function ActivateWrapper()
	destroyer.Activate(SaveGame)
end

local function Box(pos)
	return {l = pos.x + 28, r = pos.x + 36, b = pos.y + 8, t = pos.y + 16}
end

local occlusionColor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }

local function Put(pos, z, yofs)
	z = z or -0.5
	local occlusionPos = { x = pos.x - 16, y = pos.y }
	util.PutAnimTile(staticBody, img, pos, z, eapi.ANIM_LOOP, 32)	
	eapi.SetAttributes(eapi.NewTile(staticBody, occlusionPos,
					nil, Occlusion.boxFalloff, z - 0.1),
			   { size = { 96, 128 }, color = occlusionColor })
	action.MakeActivator(Box(vector.Offset(pos, 0, yofs or 0)),
			     ActivateWrapper, txt.console)
	util.PreloadSound("sound/modem.ogg")
end

local medImg = eapi.NewSpriteList("image/wood.png", {{256, 64}, {64, 64}})

local function RestoreHealth(Continue)
	local function Fill()
		if game.GetState().lives < game.GetState().maxLives then
			game.GetState().lives = game.GetState().lives + 1
			eapi.PlaySound(gameWorld, "sound/clang.ogg")
			eapi.AddTimer(gameWorld, 0.5, Fill)
			progressBar.Lives()
		else
			Continue()
		end
	end
	Fill()
	return true
end

local function MedkitWrapper()
	destroyer.Activate(RestoreHealth)
end

local shadeColor = { r = 1.0, g = 1.0, b = 1.0, a = 0.5 }

local function Medkit(pos, side, shade)
	side = side or 16
	local occlusionPos = { x = pos.x - side, y = pos.y - side }
	local occSize = { 64 + 2 * side, 64 + 2 * side } 
	eapi.NewTile(staticBody, pos, nil, medImg, -0.5)
	local function Occlude(color, z)
		eapi.SetAttributes(eapi.NewTile(staticBody, occlusionPos,
						nil, Occlusion.boxFalloff, z),
				   { size = occSize, color = color })
	end
	Occlude(occlusionColor, -0.6)
	if shade then Occlude(shadeColor, -0.4) end
	action.MakeActivator(Box(pos), MedkitWrapper, txt.medKit)
end

local function Medkit2(pos)
	Medkit(pos, 8)
end

local function Medkit3(pos)
	Medkit(pos, nil, true)
end

savePoint = {
	Put = Put,
	Medkit = Medkit,
	Medkit2 = Medkit2,
	Medkit3 = Medkit3,
}
return savePoint
