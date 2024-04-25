rock = util.TextureToTileset("image/blue-rock.png",
			     tileMap8x8, {64, 64})

local rockCrack = util.TextureToTileset("image/blue-rock-cracks.png",
					tileMap8x8, {64, 64})

function WaterfallTile(tile, x, y, z, attr)	
	if tile == ' ' then return end 
	crackTile = tile
	probability = 0.7
	if tile == 's' or tile == 't' then
		if util.Random() <= 0.8 then
			local row = RandomElement(tileMap8x8)
			local i = util.Random(1, 8)
			crackTile = string.sub(row, i, i)
		end
		probability = 1.0
	end	
	if attr then
		util.PutTileWithAttribute(staticBody, tile, 
					  rock, {x=x, y=y}, z, attr)
 		if (util.Random() <= probability) then
			util.PutTileWithAttribute(staticBody, 
						  crackTile, rockCrack,
						  {x=x, y=y}, z + 0.1, attr)
		end
	else		
		util.PutTile(staticBody, tile, rock, { x = x, y = y }, z)
		if (util.Random() <= probability) then
			util.PutTile(staticBody, crackTile, rockCrack, 
				     { x = x, y = y }, z + 0.1)
		end
	end
end

bamboo = util.TextureToTileset("image/bamboo.png",
			       { "1234", "5678", "abcd", "efgh" },
			       {64, 64})

local function PutSpike(pos)
	local info = { pos = pos, w = 64, h = 64 }
	util.PutTile(staticBody, 'e', bamboo, pos, 0.5)
	local shape = {l = pos.x + 16, r = pos.x + 48,
		       t = pos.y + 48, b = pos.y + 47}
	local shapeObj = eapi.NewShape(staticBody, nil, shape, "KillerActor")
	eapi.pointerMap[shapeObj] = info
end

function DarkRock(tile, x, y, depth)
	WaterfallTile(tile, x, y, depth, {color={ r=0.5, g=0.5, b=0.5}})
end

function SolidRock()
	return RandomElement({'t','s'})
end

local decorators = util.TextureToTileset("image/rock-decorators.png",
					 { "12", "34" },
					 {128, 128})

function PutDecorator(x, y)
	util.PutTileWithAttribute(staticBody, RandomElement({'1','2','3','4'}),
				  decorators, {x = x, y = y}, 5 + util.Random(),
				  { flip = { util.ToBeOrNotToBe(),
					     util.ToBeOrNotToBe() }})
end

function DecoratorField(x, y, w, h, i)
	for ii = 0, i, 1 do
		PutDecorator(x + 16 * util.Random(0, w / 16),
			     y + 16 * util.Random(0, h / 16))
	end
end

cave = {
	PutSpike = PutSpike,
}