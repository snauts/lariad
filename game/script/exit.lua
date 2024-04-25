
local function PlayerVsExit(world, playerShape, exitShape)
	local exit = eapi.pointerMap[exitShape]
	local player = eapi.pointerMap[playerShape]
	local vel = player.vel
	
	if exit.name then
		exit.active = true
		player.activator = exit
		if not(exit.info) then
			exit.info = util.GameInfo(exit.name, camera)
		end
	end

	if not exit.needs_upkey then
		-- Should player be facing left in the next room?
		local flip = false
		if not exit.direction or exit.direction == 0 then
			flip = player.direction
		elseif exit.direction < 0 then
			flip = true
		end
		
		local function PlacePC()
			destroyer.Place(player, exit.placement, flip)
			player.vel = vel
		end
		util.GoTo(exit.where_to, PlacePC, nil, exit.fadeEffect)
		return
	end
	
	if player.Up() and player.contact.ground then
		-- Should player be facing left in the next room?
		local flip = false
		if not exit.direction or exit.direction == 0 then
			flip = player.direction
		elseif exit.direction < 0 then
			flip = true
		end
		
		-- Disable player controls, and start playing turning animation.
		destroyer.Turn(player)
		
		-- Let the animation play, then after a brief moment go to next
		-- as usual.
		local function DelayedExit()
			local function PlacePC()
				destroyer.Place(player, exit.placement, flip)
			end
			util.GoTo(exit.where_to, PlacePC, nil, exit.fadeEffect)
		end
		eapi.AddTimer(player.body, 0.4, DelayedExit)
		
		-- Remove shape so that we don't end up in this function again.
		eapi.Destroy(playerShape)
	end
end

--[[
Create a shape that, once hit by the player shape, will take player to another
room (execute that room's script file).

	shape			Exit shape table that can be passed into
				eapi.NewShape().
	where_to		Script filename to execute.
	placement		Where to place player in the new room.
	direction		Determines whether player's tile is flipped in
				the next room or not. Assuming that in the image
				player is facing right, direction has the
				following meanings:
					-1 -- facing left
					 1 -- facing right
					 0 -- same as when exiting the old room
	needs_upkey		If true, require that the "up" key be pressed in
				order to transition to the where_to room.
]]--
function ExitRoom(shape,
		  where_to,
		  placement,
		  direction,
		  needs_upkey,
		  name, 
		  fadeEffect)
   local exit = { }
   exit.name = name
   exit.where_to = where_to
   exit.placement = placement
   exit.shape = eapi.NewShape(eapi.GetStaticBody(gameWorld), nil, shape, "Exit")
   exit.direction = direction
   exit.needs_upkey = needs_upkey
   exit.fadeEffect = fadeEffect
   eapi.pointerMap[exit.shape] = exit
end

eapi.Collide(gameWorld, "Player", "Exit", PlayerVsExit)
