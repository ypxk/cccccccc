--lfos 
--trying to make this a thing

local lfo = {}

for i=1,4 do
	lfo[i] = {}
	lfo[i].freq = ((math.random(1,10)-5)/10)*3
	lfo[i].cc = 1
	lfo[i].amp = .5
	lfo[i].offset = 64
	lfo[i].ccmin = 0
	lfo[i].ccmax = 127
	lfo[i].lastphase = 1
	lfo[i].counter = 1
	lfo[i].newfreq = lfo[i].freq
	lfo[i].newcc = lfo[i].cc 
end

local ar = arc.connect()
local md = midi.connect()
local framerate = 40
local arcDirty = true
local startTime 
local tau = math.pi * 2
local phaseReset = false
local counter = 1
local lastTouched = 1
local options = {}
options.knobmodes =	{"sine", "knob"}


engine.name = "PolyPerc"

function init()

	local paramknobs = {}
	params: add_number("midi_chan", "midi chan", 1, 16, 1) 

	for a=1,4 do 
		paramknobs[a] = {}
		paramknobs[a].name = "Arc " .. a .. " Mode"
		paramknobs[a].id = "arc_" .. a .. "_mode"
		params:add{type = "option", name = paramknobs[a].name, id = paramknobs[a].id, options = options.knobmodes, default = 1,
			action = function(value)
			end}
			params:add_control("knob_" .. a .. "_amp", "knob " .. a .. " amp", controlspec.new(0,1,"lin",0.01,.5))
			params:add_control("knob_" .. a .. "_offset", "knob " .. a .. " offset", controlspec.new(0,127,"lin",1,64))

	end


	startTime = util.time()
  lfo_metro = metro.init()
  lfo_metro.time = .01
  lfo_metro.count = -100
	lfo_metro.event = function()
		currentTime = util.time()
		for i = 1,4 do 
			if params:get("arc_" .. i .. "_mode") == 2 then 
				lfo[i].freq = 0
				lfo[i].bpm = 0 

			else
				lfo[i].bpm = lfo[i].freq * 60
				lfo[i].amp = params:get("knob_" .. i .. "_amp")
				lfo[i].offset= params:get("knob_" .. i .. "_offset")
				lfo[i].phase = math.sin((currentTime - startTime) * lfo[i].freq* tau)
				if math.ceil(lfo[i].offset + 64 * lfo[i].phase * lfo[i].amp) < 0 then 
					lfo[i].cc = 0
				elseif math.ceil(lfo[i].offset + 64 * lfo[i].phase * lfo[i].amp) > 127 then
					lfo[i].cc = 127
				else
					lfo[i].cc= math.ceil(lfo[i].offset + 64 * lfo[i].phase * lfo[i].amp)
				end
				lfo[i].counter = (lfo[i].counter + (1*lfo[i].freq))%100
				lfo[i].ar = lfo[i].counter*.64


				lfo[i].lastphase = lfo[i].phase
				send_cc(i,lfo[i].cc)
			end
		end

		end

  lfo_metro:start()
  local arc_redraw_metro = metro.init()
	arc_redraw_metro.event = function()
			arc_redraw()
			redraw()
	end
	arc_redraw_metro:start(1 /framerate)
end

function send_cc(num,val)
		md:cc(num,val,params:get("midi_chan"))


end


function ar.delta(n, delta)
	if params:get("arc_" .. n .. "_mode") == 2 then 
	--knob mode
		valueChange = delta + (delta/10)
		if valuechange then 
		else
			if delta > 0 then
				lfo[n].cc = math.ceil(math.max(0, math.min((lfo[n].cc + delta/10), 127)))
			elseif delta < 0 then 
				lfo[n].cc = math.floor(math.max(0, math.min((lfo[n].cc + delta/10), 127)))
			end

		end


	else
	--lfo mode
	--
		startTime = util.time()
		if lfo[n].newfreq == lfo[n].freq then
			lfo[n].newfreq = lfo[n].freq + (delta/500)
		elseif lfo[n].newfreq ~= lfo[n].freq then
			lfo[n].newfreq = lfo[n].newfreq + (delta/500)
		end
		lfo[n].newphase = math.sin((currentTime - startTime) * lfo[n].freq* tau)
		lfo[n].newcc= math.ceil(64 + 64 * lfo[n].newphase * lfo[n].amp)
			lfo[n].freq = lfo[n].newfreq
	end

	lastTouched = n
	arcDirty = true
end

function enc(n, delta)
	if n == 1 then
		if delta < 0 and lastTouched == 1 then 
			lastTouched = 4
		end
		if (lastTouched + delta)%5 == 0  then
			lastTouched = 1
		else
			lastTouched = ((lastTouched + delta)%5) 
		end
	elseif n == 2 then
		params:delta("knob_" .. lastTouched .. "_amp",delta)
	elseif n == 3 then
		params:delta("knob_" .. lastTouched .. "_offset",delta)
	end

	acrDirty = true

end

function arc_redraw()
	local brightness 
	ar:all(0)

	for a=1,4 do
		--knob mode
		if params:get("arc_" .. a .. "_mode") == 2 then 
			local ccVal = math.floor((lfo[a].cc/127)*64)
			if ccVal < 64 then
				ar:segment(a,0, ccVal/10.1, 8) 
				ar:led(a,ccVal,15)
			else 
				ar:segment(a,0, tau-.1, 8)
				ar:led(a,ccVal,15)
			end







			
		--lfo mode
		else
		brightness = math.floor(lfo[a].amp * 15)
		seg = lfo[a].ar/64
		ar:segment(a,seg*tau,tau*seg+.2,brightness)
		end
	end
	ar:refresh()
end


function redraw()
  screen.clear()
  screen.font_face(1)
  screen.font_size(8)
	local x,y = 15, 0
	local COLS = 5
	--cleaner way to display rounded numbers??
	local screenVars = {
		'lfo:',1,2,3,4,
		'frq:',math.floor(lfo[1].freq*100)/100,math.floor(lfo[2].freq*100)/100,math.floor(lfo[3].freq*100)/100,math.floor(lfo[4].freq*100)/100,
		'bpm:',math.abs(math.floor(lfo[1].bpm*100)/100),math.abs(math.floor(lfo[2].bpm*100)/100),math.abs(math.floor(lfo[3].bpm*100)/100),math.abs(math.floor(lfo[4].bpm*100)/100),
		' cc:',lfo[1].cc,lfo[2].cc,lfo[3].cc,lfo[4].cc,
		'amp:',lfo[1].amp,lfo[2].amp,lfo[3].amp,lfo[4].amp,
		'off:',lfo[1].offset,lfo[2].offset,lfo[3].offset,lfo[4].offset,
	}


	screen.move(0,5)
	for i = 1,35 do
		--column 5
		if (i-1)%COLS == 0 then 
			x,y = 0, y + 8
		end
		if (i-1)%COLS == lastTouched then 
			screen.level(15)
		else
			screen.level(5)

		end
		screen.move(x,y)

		if screenVars[i] ~= nil then
			screen.text(screenVars[i])
		else
			screen.text('--')
		end
		x = x + 25
	end


  screen.update()
  end
