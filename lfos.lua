-- lfos 
-- v1.0.0
--
-- set midi cc values by arc 
-- encoder 1: scroll 
-- encoder 2: set amp
-- encoder 3: set offset

local ar = arc.connect()
local md = midi.connect()
local framerate = 40
local arcDirty = true
local startTime 
local tau = math.pi * 2
local lastTouched = 1
local newSpeed = false
local slewer = 1 
local seed = math.random(1,127)
local options = {}
options.knobmodes =	{"lfo", "val"}
options.lfotypes = {"sin","saw","sqr","rnd"}

local lfo = {}

for i=1,4 do
	lfo[i] = {}
	lfo[i].init = math.random(1,4)
	lfo[i].freq = (math.random(1,10)-5)/10
	lfo[i].newfreq = freq
	lfo[i].cc = 1
	lfo[i].counter = 1
	lfo[i].waveform = options.lfotypes[lfo[i].init]
	lfo[i].interpolater = 1
end

function init()
	local paramknobs = {}
	for a=1,4 do 
		paramknobs[a] = {}
		paramknobs[a].name = "arc " .. a .. " mode"
		paramknobs[a].id = "arc_" .. a .. "_mode"
		if a < 5 then 
			params:add{type = "option", name = paramknobs[a].name, id = paramknobs[a].id, options = options.knobmodes, default = 1,
				action = function(value)
				end}
		else
			params:add{type = "option", name = paramknobs[a].name, id = paramknobs[a].id, options = options.knobmodes, default = 2,
				action = function(value)
				end}
		end
		params:add{type = "option", name = "lfo " .. a .." type" , id = "lfo_" .. a .. "_type", options = options.lfotypes, default = lfo[a].init,
			action = function(value)
				lfo[a].waveform = options.lfotypes[value]
				if lfo[a].waveform == "saw" then lfo[a].ccoffset = 127 end
				if lfo[a].freq == 0 then lfo[a].freq = (math.random(1,10)-5)/10 end
			end}
		params:add_control("lfo_" .. a .. "_ccamp", "lfo " .. a .. " amp", controlspec.new(0,1,"lin",0.01,.5))
		params:add_control("lfo_" .. a .. "_ccoffset", "lfo " .. a .. " offset", controlspec.new(-127,127,"lin",1,0))
		params:add_separator()
	end
	params: add_number("midi_chan", "midi chan", 1, 16, 1) 

	startTime = util.time()
  lfo_metro = metro.init()
  lfo_metro.time = .01
  lfo_metro.count = -1000
	lfo_metro.event = function()
		currentTime = util.time()
		for i = 1,4 do 
			--knob mode
			if params:get("arc_" .. i .. "_mode") == 2 then 
				lfo[i].freq = 0
				lfo[i].bpm = 0 
				send_cc(i,lfo[i].cc)
			else
				--lfo mode
				lfo[i].bpm = lfo[i].freq * 60
				lfo[i].ccamp = params:get("lfo_" .. i .. "_ccamp")
				lfo[i].ccoffset= params:get("lfo_" .. i .. "_ccoffset")
				lfo[i].prevcc = lfo[i].cc

				if lfo[i].waveform == "saw" then
					lfo[i].slope = lfo[i].ccamp * (-(127/99)*lfo[i].counter) + (127/99) +  lfo[i].ccoffset + 64
				
				elseif lfo[i].waveform == "sin" then
					lfo[i].slope = lfo[i].ccamp * math.abs(127 * math.sin(((tau/100)*(lfo[i].counter))-(tau/(lfo[i].freq)))) + lfo[i].ccoffset
				
				elseif lfo[i].waveform == "sqr" then
					if math.cos(((tau/100)*(lfo[i].counter))-(tau/(lfo[i].freq))) > 0 then 
						lfo[i].slope = lfo[i].ccoffset + (127 * lfo[i].ccamp)
					else
						lfo[i].slope =  lfo[i].ccoffset + (1 * lfo[i].ccamp)
					end
				
				elseif lfo[i].waveform == "rnd" then
					if slewer==1 then
						seed = math.random(1,127)
						lfo[i].slope = lfo[i].ccoffset + (lfo[i].ccamp * slew(lfo[i].prevcc,seed))
					else
						lfo[i].slope = lfo[i].ccoffset + (lfo[i].ccamp * slew(lfo[i].prevcc,seed))
					end
				end

				lfo[i].slope = math.max(0,math.min(127,lfo[i].slope))
			
				if newSpeed == true then 
					interpolate(lfo[i].prevcc,math.abs(math.floor(lfo[i].slope)),i)
				else
					lfo[i].cc = math.abs(math.floor(lfo[i].slope))
				end

				lfo[i].counter = ((lfo[i].counter + (1*lfo[i].freq)))%100
				
				if lfo[i].waveform == "rnd" then 
					lfo[i].ar = (100 * (lfo[i].cc/127)) * .64
				else
					lfo[i].ar = lfo[i].counter*.64
				end
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

--helper functions 
function send_cc(num,val)
		md:cc(num,val,params:get("midi_chan"))
end

function interpolate(old,new,i)
	if lfo[i].interpolater == 0 then lfo[i].interpolater = 50 end
	t = lfo[i].interpolater/50
	lfo[i].cc = math.floor((old + ((new-old)*t)))
	if lfo[i].interpolater == 50 then newSpeed = false end
	lfo[i].interpolater = (lfo[i].interpolater + 1)%50 
end

function slew(old,new)
	slewer = (slewer+1)%20
	if slewer == 0 then slewer = 20 end
	return old + ((new-old)*(slewer/20))
end

--hardware functions

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
		if lfo[n].interpolater == 1 then
			lfo[n].freq = lfo[n].freq + (delta/50)
			newSpeed = true
		end
		lfo[n].interpolater = 1

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
		params:delta("lfo_" .. lastTouched .. "_ccamp",delta)
	elseif n == 3 then
		params:delta("lfo_" .. lastTouched .. "_ccoffset",delta)
	end
	acrDirty = true
end

function key(n,z)
	if n == 3 then
		if z == 1 then
			print('remember')
		end
	end
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
			brightness = math.floor(lfo[a].ccamp * 15)
			seg = lfo[a].ar/64
			ar:segment(a,seg*tau,tau*seg+.2,brightness)
		end
	end
	ar:refresh()
end


function redraw()
  screen.clear()
	--[[screen.move(0,60)
	screen.text(math.floor(lfo[1].counter) .. " " .. lfo[1].cc.. " " .. lfo[1].freq)
	screen.level(15)
	screen.pixel(math.abs(math.floor(lfo[1].counter)),lfo[1].cc/2)
	screen.fill()]]
  screen.font_face(1)
  screen.font_size(8)
	local x,y = 15, 0
	local COLS = 5
	--cleaner way to display rounded numbers??
	local screenVars = {
		'lfo:',1,2,3,4,
		'type:', lfo[1].waveform,lfo[2].waveform,lfo[3].waveform,lfo[4].waveform,
		'frq:',math.floor(lfo[1].freq*100)/100,math.floor(lfo[2].freq*100)/100,math.floor(lfo[3].freq*100)/100,math.floor(lfo[4].freq*100)/100,
		'amp:',lfo[1].ccamp,lfo[2].ccamp,lfo[3].ccamp,lfo[4].ccamp,
		'off:',lfo[1].ccoffset,lfo[2].ccoffset,lfo[3].ccoffset,lfo[4].ccoffset,
		' cc:',lfo[1].cc,lfo[2].cc,lfo[3].cc,lfo[4].cc,
	}

	--[[local screenVars = {
		'lfo:',1,2,3,4,
		'frq:',math.floor(lfo[1].freq*100)/100,math.floor(lfo[2].freq*100)/100,math.floor(lfo[3].freq*100)/100,math.floor(lfo[4].freq*100)/100,
		'bpm:',math.abs(math.floor(lfo[1].bpm*100)/100),math.abs(math.floor(lfo[2].bpm*100)/100),math.abs(math.floor(lfo[3].bpm*100)/100),math.abs(math.floor(lfo[4].bpm*100)/100),
		' cc:',lfo[1].cc,lfo[2].cc,lfo[3].cc,lfo[4].cc,
		'amp:',lfo[1].ccamp,lfo[2].ccamp,lfo[3].ccamp,lfo[4].ccamp,
		'off:',lfo[1].ccoffset,lfo[2].ccoffset,lfo[3].ccoffset,lfo[4].ccoffset,
	}]]


	screen.move(0,5)
	for i = 1,30 do
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
