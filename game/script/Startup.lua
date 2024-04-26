dofile(Cfg.texts or "script/Texts.lua")
dofile("script/occlusion.lua")
dofile("script/exit.lua")

local mainMenu = true
local camBox = {l=-400,r=400,b=-240,t=240}
camera = util.CreateCamera(gameWorld, nil, camBox)
eapi.SetBackgroundColor(gameWorld, {r=0.05, g=0.05, b=0.05})

staticBody = eapi.GetStaticBody(gameWorld)

local bg = eapi.NewSpriteList("image/menu-bg.png", { {0, 0}, {800, 480} })
eapi.NewTile(staticBody, {-400, -240}, nil, bg, -10)

local walkAnim = eapi.TextureToSpriteList("image/menu-walk.png", { 192, 256 })

util.PutAnimTile(staticBody, walkAnim, {150, -200}, 0, eapi.ANIM_LOOP, 24, 0)

local function DialogPositioner(totalSize, boxSize, axis)
	if axis == "x" then return 64 end
	if axis == "y" then return 96 end
end

local function LoadGame() 
	game.Load(nil, true)
end

local function Quit()
	Occlusion.put('f', -400, -240, 1000, {size = {800, 480}}, camera.ptr)
	eapi.FadeFramebuffer(eapi.CROSSFADE)
	eapi.AddTimer(staticBody, 1.0, eapi.Quit)
end

local languages = {
	["script/Texts.lua"] = "script/Texts.en.lua",
	["script/Texts.en.lua"] = "script/Texts.lua",
}

local function SwitchLanguage()
	Cfg.texts = languages[Cfg.texts]
	util.SaveSetup()
	util.GoTo("Startup", nil, true)
end

local function Training()
	game.ResetState()
	game.GetState().maxLives = 2
	util.GoToAndPlace("Training", mainPC, {-185, -132}, false)
end

local function StartGame(lives)
	return function()
		Cfg.startLives = lives
		util.GoTo("Intro")
	end
end

local newGameItems = { { active = true,
			 text = txt.Easy,
			 fn = StartGame(3) },
		       { active = true,
			 text = txt.Normal,
			 fn = StartGame(1) }, }

local function NewGameMenu()
	mainMenu = false
	newGameMenu = menu.Show(nil, true, DialogPositioner,
				newGameItems, txt.Difficulty)
end

local function PutStr(pos, str, tint)
	local strings = { str }
	util.MaxWidth(strings)
	local text = { { str = strings[1], ink = util.Gray(tint) } }
	util.CreateViewportLines(text, staticBody, pos)
end

local function Wrap(Fn)
	return function(key, keyDown)
		       if keyDown then Fn(key) end
	       end
end

local function Configure()
	local selectTile	= nil
	local camSize		= eapi.GetSize(camera.ptr)
	local keyColor		= { r = 0.35, g = 0.35, b = 0.35, a = 0.20 }
	local selectColor	= { r = 0.35, g = 0.35, b = 0.35, a = 0.30 }
	local chooseColor	= { r = 0.35, g = 0.00, b = 0.00, a = 0.30 }
	local selected		= { x = 1, y = 1 }
	local keyBox		= { }

	mainMenu = false

	local configKeys = {
		Cfg.keyUp,
		Cfg.keyDown,
		Cfg.keyLeft,
		Cfg.keyRight,
		Cfg.keyShoot,
		Cfg.keyJump,
		Cfg.keyESC,
	}
	
	local function DialogAtPos(x, y)
		return function (totalSize, boxSize, axis)
			if axis == "x" then return x end
			if axis == "y" then return y end
		end
	end
	
	local function ExitKeyConfig()
		util.Click()
		util.SaveSetup()
		util.GoTo("Startup", nil, true)	
	end
	
	local function XPos(j)
		return 80 + j * 100
	end

	local function YPos(i)
		return 40 + i * 40
	end

	local function Select(pos)
		if selectTile then eapi.Destroy(selectTile) end
		local attr = { size = { 96, 40 }, color = selectColor }
		local x = XPos(pos.x) - camSize.x / 2 - 16
		local y = camSize.y / 2 - YPos(pos.y) - 28
		selectTile = Occlusion.put('h', x, y, 90, attr, staticBody)
	end

	local function Clamp(i, val)
		return ((i - 1) % val) + 1
	end

	local function Move(delta)
		return function()
			util.Tik()
			selected = vector.Add(selected, delta)
			selected.x = Clamp(selected.x, 4)
			selected.y = Clamp(selected.y, #configKeys)
			Select(selected)
		end
	end

	local function DisplayKeyBox(i, j)
		local idx = 4 * j + i
		configKeys[j][i] = configKeys[j][i] or 0
		local pos = DialogAtPos(XPos(i), YPos(j))
		local keyName =  { eapi.KeyNames[configKeys[j][i]] or "???" }
		if keyBox[idx] then util.Map(eapi.Destroy, keyBox[idx]) end
		keyBox[idx] = util.DialogBox(keyName, camera, pos, 80, keyColor)
	end

	for j = 1, #configKeys, 1 do
		local pos = DialogAtPos(50, YPos(j))
		util.DialogBox({ txt.Buttons[j] }, camera, pos, 100)
		for i = 1, 4, 1 do
			DisplayKeyBox(i, j)
		end
	end

	local function DelKey()
		configKeys[selected.y][selected.x] = 0
		DisplayKeyBox(selected.x, selected.y)
		util.Click()
	end

	local BindConfigKeys
	local function InterceptKey(key)
		configKeys[selected.y][selected.x] = key
		DisplayKeyBox(selected.x, selected.y)
		eapi.SetAttributes(selectTile, { color = selectColor })
		util.BindAllKeys(nil)
		BindConfigKeys()
		util.Click()
	end

	local function ChooseKey()
		eapi.SetAttributes(selectTile, { color = chooseColor })
		util.BindAllKeys(Wrap(InterceptKey))
		util.Click()
	end

	local function Bind(key, Fn)
		eapi.BindKey(key, Wrap(Fn))
	end

	BindConfigKeys = function()
		Bind(eapi.KEY_LEFT,   Move({ x = -1, y = 0 }))
		Bind(eapi.KEY_RIGHT,  Move({ x =  1, y = 0 }))
		Bind(eapi.KEY_UP,     Move({ x = 0, y = -1 }))
		Bind(eapi.KEY_DOWN,   Move({ x = 0, y =  1 }))
		Bind(eapi.KEY_DELETE, DelKey)
		Bind(eapi.KEY_RETURN, ChooseKey)
		Bind(eapi.KEY_ESCAPE, ExitKeyConfig)
	end
	
	PutStr({ x = -390, y = 230 }, txt.bindingsHelp, 0.8)

	Select(selected)
	BindConfigKeys()
end

local items = { { active = true,
		  text = txt.New,
		  fn = NewGameMenu },
		{ active = game.HasSaavgaam(),
		  text = txt.Load,
		  fn = LoadGame },
--		{ active = true,
--		  text = txt.Training,
--		  fn = Training },
		{ active = true,
		  text = txt.Config,
		  fn = Configure },
		{ active = true,
		  text = txt.Language,
		  fn = SwitchLanguage },
		{ active = true,
		  text = txt.Quit,
		  fn = Quit } }

menu.Show(nil, true, DialogPositioner, items)

PutStr({ x = 260, y = -220 }, txt.version .. Cfg.version, 0.4)
PutStr({ x = -50, y = -220 }, txt.email, 0.3)
PutStr({ x = 20, y = -220 }, txt.emailAddress, 0.5)

local function Exit()
	if not(mainMenu) then 
		util.GoTo("Startup", nil, true)	
	else
		menu.Kill()
		Quit()
	end
end

util.BindKeys(Cfg.keyESC, Wrap(Exit))
