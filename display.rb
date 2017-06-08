#!/usr/bin/env ruby
require 'fileutils'
require 'ruby-osc'
require 'ruby2d'

include OSC
client = Client.new 9091

bpm = 132.0
w = 1920
h = 1080
set width: w
set height: h

stems = Array.new(4);
samples = 0
eightbar_samples = 44100 * 8 * 8 * 30/bpm
grid = []
gridnr = 0

looprange = Rectangle.new(0, 0, 0, h, [0.3,0.3,0.3,0.5])
cursor = Rectangle.new(0, 0, 0, h, "green")
slice = Rectangle.new(0, 0, w*eightbar_samples/samples, h, [0.2,0.2,0.2,0.2])

looping = false
select_loop = false
loop_in = 0
loop_out = 0

on :mouse_move do |event|
  gridnr = grid.index( grid.select{|g| event.x < g}.first)
  gridnr = grid.size unless gridnr
  gridnr -= 1
  select_loop ? looprange.width = grid[gridnr+1]-grid[loop_in] : slice.x = grid[gridnr]
end

on :mouse_down do |event|
  if select_loop
  else
    case event.button
    when :left
      client.send Message.new('/goto/8bar/quant', gridnr)
    when :right
      client.send Message.new('/goto/8bar/nextbar', gridnr)
    end
  end
end

on :key_down do |event|
  case event.key
  when 'escape'
    client.send Message.new('/stop')
    close
  when 'a'
    dir = `ls -d ~/music/live/dj/* | dmenu -l 20`.chomp
    client.send Message.new('/load', dir)
    clear
    Dir["#{dir}/[0-3].wav"].each_with_index do |st,i|

      if File.exists?(st)
        img = st.sub('wav','png')
        unless (File.exists?(img) and FileUtils.uptodate?(img,[st]))
          `ffmpeg -y -i "#{st}" -filter_complex 'showwavespic=s=#{w}x#{h/4}:colors=white[a];color=s=#{w}x#{h/4}:color=black[b];[b][a]overlay'  -frames:v 1 "#{img}"`
        end
        stems[i] = Image.new(0,i*h/4,img)
        stems[i].width = w
        stems[i].height = h/4
      end
    end
    samples = `soxi "#{dir}/0.wav" |grep Duration|cut -d '=' -f2|sed  's/samples//'|tr -d " "`.to_i
    pos = 0
    grid = []
    while (pos <= w) do
      grid << pos
      grid.size % 4 == 0 ? Rectangle.new(pos, 0, 1, h, [1,1,1,0.5]) : Rectangle.new(pos, 0, 1, h, [0.5,0.5,0.5,0.5])
      pos += w*eightbar_samples/samples
    end
    slice = Rectangle.new(0, 0, w*eightbar_samples/samples, h, [0.5,0.5,0.5,0.5])
    cursor = Rectangle.new(0, 0, 1, h, "green")
    looprange = Rectangle.new(0, 0, 0, h, [0.3,0.3,0.3,0.5])
  when '/'
    looping = !looping
    looping ? client.send(Message.new('/loop/on')) : client.send(Message.new('/loop/off'))
    looping ? looprange.color = [0.5,0.2,0.2,0.5] : looprange.color = [0.3,0.3,0.3,0.5]
  when "left shift"
    loop_in = gridnr
    looprange.x = grid[loop_in]
    looprange.width = grid[1]-grid[0]
    select_loop = true
  when "backspace"
    client.send Message.new('/stop')
  when 'space'
    client.send Message.new('/goto/8bar/now', gridnr)
  when 'right'
    client.send Message.new('/speed/up')
  when 'left'
    client.send Message.new('/speed/down')
  else
    p event.key
  end
end

on :key_up do |event|
  case event.key
  when "left shift"
    loop_out = gridnr + 1
    client.send Message.new('/loop/set/8bar', loop_in, loop_out)
    select_loop = false
  when 'right'
    client.send Message.new('/speed/normal')
  when 'left'
    client.send Message.new('/speed/normal')
  end
end

thr = Thread.new do
  OSC.run do
    server = Server.new 9090
    server.add_pattern "/phase" do |*args|
      cursor.x = args[1]*w
    end
  end
end

show
