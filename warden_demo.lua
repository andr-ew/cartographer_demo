--warden demo
--six loop pedals
--
-- v1 @andrew
-- E1: loop page
-- K1: punch in / record
-- K2: clear
-- E2: loop start
-- E3: loop end

function r() norns.script.load(norns.script.state) end

warden = include 'lib/warden/warden'

--global variables
count = 6
pg = 1
quant = 0.01
sens = 0.01

--warden setup
reg = {}
reg.blank = warden.divide(warden.buffer, count) --available loop region
reg.rec = warden.subloop(reg.blank) --initial recorded loop region
reg.play = warden.subloop(reg.rec) --playback loop region

--softcut data
sc = {}
for i = 1,count do
    sc[i] = {
        play = 0, pre = 1, rec = 0, recording = false, recorded = false, clock = nil, t = 0, rate = 1, phase = 0, play = 0
    }
end

--softcut setup
sc.setup = function()
    audio.level_cut(1.0)
    audio.level_adc_cut(1)
    audio.level_eng_cut(1)

    for i = 1, count do
        softcut.enable(i, 1)
        softcut.rec(i, 1)
        softcut.loop(i, 1)
        softcut.level_slew_time(i, 0.1)
        softcut.recpre_slew_time(i, 0.1)
        softcut.rate(i, 1)
        softcut.level_input_cut(1, i, 1)
        softcut.level_input_cut(2, i, 1)
        softcut.phase_quant(i, 1/25)
        softcut.play(i, 0)
        softcut.level(i, 1)

        warden.assign(reg.play[i], i)
        reg.play:position(i, 0)
    end

    local function e(i, ph)
        if sc[i] then sc[i].phase = ph end
        if i == count then redraw() end
    end

    softcut.event_phase(e)
    softcut.poll_start_phase()
end

--update rec_level & pre_level
sc.update_recpre = function(s, n)
    softcut.rec_level(n, s[n].rec)

    if s[n].rec == 0 then
        softcut.pre_level(n, 1)
    else 
        softcut.pre_level(n, s[n].pre)
    end
end

--loop pedal punch in
sc.punch_in = function(s, i, v)
    if s[i].recorded then
        s[i].rec = v; s:update_recpre(i)
    elseif v == 1 then
        reg.play:position(i, 0)
        s[i].rec = 1; s:update_recpre(i)
        s[i].play = 1; softcut.play(i, 1)

        reg.rec:punch_in(i)

        s[i].recording = true
    elseif s[i].recording then
        s[i].rec = 0; s:update_recpre(i)

        reg.rec:punch_out(i)

        s[i].recorded = true
        s[i].recording = false
    end
end

--softcut clear
sc.clear = function(s, i)
    s[i].rec = 0; s:update_recpre(i)
    s[i].play = 0; softcut.play(i, 0)
    reg.play:position(i, 0)

    reg.rec:punch_out(i)
    reg.rec:clear(i)

    s[i].recorded = false
    s[i].recording = false

    reg.rec:expand(i)
end

function init()
    sc.setup()
end

--user interface

function key(n, z)
    local i = math.floor(pg)

    if z == 1 then
        if n == 2 then sc:punch_in(i, sc[i].rec+1 & 1) --K2 is a loop pedeal punch-in
        elseif n == 3 then sc:clear(i) end --K3 clears the loop
    end
    redraw()
end

function enc(n, d)
    local i = math.floor(pg)

    if n == 1 then 
        pg = util.clamp(pg + (d * 0.5), 1, count) --E1 controls page
    elseif sc[i].recorded then
        if n == 2 then 
            reg.play:delta_start(i, d * sens, 'seconds') --E2 controls loop start
        elseif n == 3 then 
            reg.play:delta_end(i, d * sens, 'seconds') --E3  controls loop end
        end 
    end 
    
    redraw()
end

x = { 2, 64, 128 - 2 }
w = x[#x] - x[1]
y = { 64/4, 64/4 * 2, 64/4 * 3 }
lvl = { 2, 8, 15 }

function redraw()
    local i = math.floor(pg)
    screen.clear()
    screen.aa(0)

    --encoders
    screen.level(lvl[3])
    screen.move(x[1], y[1])
    screen.text(i)
    
    if sc[i].recorded then
        screen.move(x[1], y[2])
        screen.text('start: '..util.round(reg.play:get_start(i, 'seconds'), 0.01))
        screen.move(x[2], y[2])
        screen.text('end: '..util.round(reg.play:get_end(i, 'seconds'), 0.01))
    end
    
    local scale = 10

    --phase
    screen.pixel(math.floor(reg.blank:phase_relative(i, sc[i].phase, 'fraction')*w*scale + x[1]), math.floor(y[3]))
    screen.level(sc[i].play>0 and (sc[i].rec>0 and lvl[3] or lvl[2]) or 0)
    screen.fill()
    
    --regions
    for n,v in ipairs { 'blank', 'rec', 'play' } do
        local b = {
            reg[v]:get_start(i, 'seconds', 'absolute'),
            reg[v]:get_end(i, 'seconds', 'absolute')
        }
        for j = 1,2 do
            b[j] = (
                b[j] - reg.blank:get_start(i, 'seconds', 'absolute')
            ) / reg.blank:get_length(i)
        end

        screen.level(lvl[n])
        screen.move(b[1]*w*scale + x[1], y[3] - n*2 + 8)
        screen.line(b[2]*w*scale + x[1], y[3] - n*2 + 8)
        screen.stroke()
    end

    screen.update()
end
