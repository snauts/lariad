
local led_tileset = eapi.TextureToSpriteList("image/leds.png", {4,4})

local ledSpeed = 0.05

local LEDs = {}

local function LEDTimer()
	for i, led in ipairs(LEDs) do
		if led.delay > 0 then
			led.delay = led.delay - ledSpeed
		else
			led.animProgress = led.animProgress + ledSpeed
			if led.state == 0 then
				if led.animProgress < 0.5 then
					eapi.SetAnimPos(led.tile,
							led.animProgress)
				else
					if grayArea.holdLeds then
						led.delay = 15 * led.on_time
					else
						led.delay = led.on_time
					end
					led.state = 1		       
				end		 
			else
				if led.animProgress < 1.0 then
					eapi.SetAnimPos(led.tile,
							led.animProgress)
				else
					led.animProgress = 0.0
					led.delay = led.off_time
					led.state = 0	       
				end		 
			end
		end
	end
	eapi.AddTimer(gameWorld, ledSpeed, LEDTimer)
end

grayArea.fadeLeds = function()
	for i, led in ipairs(LEDs) do
		led.delay = util.Random()
	end
end

eapi.AddTimer(gameWorld, ledSpeed, LEDTimer)

local avg_on_duration = 2.0
local avg_off_duration = 10.0
local duration_ratio = avg_on_duration / (avg_on_duration + avg_off_duration)

local function PutLed(pos)
	local led = {}
	led.on_time = util.Random() * avg_on_duration
	led.off_time = util.Random() * avg_off_duration
	
	led.tile = eapi.NewTile(staticBody, pos, nil, led_tileset, -2)
	if (util.Random() < duration_ratio) then
		led.delay = util.Random() * led.on_time;
		led.animProgress = 0.5;
		led.state = 1;
	else
		led.delay = util.Random() * led.off_time;
		led.animProgress = 0.0;
		led.state = 0;
	end

	eapi.SetAnimPos(led.tile, led.animProgress)
	table.insert(LEDs, led)
end

for y = -48, 170, 8 do 
	for x = -302, 302, 8 do 
		PutLed({x, y})
	end
end

for y = -156, -56, 8 do 
	for x = -400, 400, 8 do 
		PutLed({x, y})
	end
end
