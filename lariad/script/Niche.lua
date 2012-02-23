util.msg = "FromNiche"

dofile("script/Forest.lua")

editor.Parse("script/Niche-edit.lua", gameWorld, forest)

common.Gradient(-400, -240, 200, 480, true,  false, Occlusion.entranceFalloff)
common.Gradient( 200, -240, 200, 480, false, false, Occlusion.entranceFalloff)
common.Gradient(-400, -240, 800, 128, false, true,  Occlusion.gradient)
common.Gradient(-400,  112, 800, 128, false, false, Occlusion.gradient)
