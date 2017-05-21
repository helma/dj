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

looprange = Rectangle.new(0, 0, 0, h, [0,1,0,0.5])
cursor = Rectangle.new(0, 0, 0, h, "green")
slice = Rectangle.new(0, 0, w*eightbar_samples/samples, h, [0.2,0.2,0.2,0.2])

select_loop = false
loop_in = 0
loop_out = 0

on :mouse_move do |event|
  gridnr = grid.index( grid.select{|g| event.x < g}.first)-1
  if select_loop
    looprange.width = grid[gridnr+1]-grid[loop_in]
  else
    slice.x = grid[gridnr]
  end
end

on :mouse_down do |event|
  gridnr = grid.index( grid.select{|g| event.x < g}.first)-1
  if select_loop
    loop_in = gridnr
    looprange.x = grid[loop_in]
  else
    case event.button
    when :left
      client.send Message.new('/goto/8bar/quant', gridnr)
    when :right
      client.send Message.new('/goto/8bar', gridnr)
    end
  end
end

on :mouse_up do |event|
  gridnr = grid.index( grid.select{|g| event.x < g}.first)
  if select_loop
    loop_out = gridnr
  end
  client.send Message.new('/loop/set/8bar', loop_in, loop_out)
  select_loop = false
end

on :key_down do |event|
  case event.key
  when 'escape'
    client.send Message.new('/stop')
    close
  when 'a'
    dir = `ls -d ~/music/live/dj/* | dmenu -l 20`.chomp
    client.send Message.new('/load', dir)
    Dir["#{dir}/[0-3].wav"].each_with_index do |st,i|

      if File.exists?(st)
        img = st.sub('wav','png')
        unless (File.exists?(img) and FileUtils.uptodate?(img,[st]))
          `ffmpeg -y -i "#{st}" -filter_complex 'showwavespic=s=#{w}x#{h/4}:colors=white[a];color=s=#{w}x#{h/4}:color=black[b];[b][a]overlay'  -frames:v 1 "#{img}"`
        end
        stems[i] = Image.new(0,i*h/4,img)
        stems[i].width = w
        stems[i].height = h/4
      else
        stems[i] = nil
        stems[i] = Rectangle.new(0, i*h/4, w, h/4, "black")
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
    looprange = Rectangle.new(0, 0, 0, h, [0.5,0.2,0.2,0.5])
  when '/'
    p "loop"
    client.send Message.new('/loop/on')
  when "left shift"
    select_loop = true
  when 'space'
    #select_loop = !select_loop
  else
    p event.key
  end
end

on :key_up do |event|
  case event.key
  when "left shift"
    select_loop = false
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
