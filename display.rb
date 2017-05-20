#!/usr/bin/env ruby
require 'fileutils'
require 'ruby-osc'
require 'ruby2d'
include OSC

bpm = 132.0
w = 1920
h = 1080
set width: w
set height: h

stems = Array.new(4);
samples = 0
eightbar_samples = 44100 * 8 * 8 * 30/bpm
grid = []
def grid_nr p
  
end

@looprange = Rectangle.new(0, 0, 0, h, [0,1,0,0.5])
cursor = Rectangle.new(0, 0, 0, h, "green")
slice = Rectangle.new(0, 0, w*eightbar_samples/samples, h, [0.2,0.2,0.2,0.2])

client = Client.new 9091

on :mouse_move do |event|
  gridnr = grid.index( grid.select{|g| event.x < g}.first)-1
  slice.x = grid[gridnr]
end

on :mouse_down do |event|
  gridnr = grid.index( grid.select{|g| event.x < g}.first)-1
  case event.button
  when :left
    client.send Message.new('/goto/8bar/quant', gridnr)
  when :right
    client.send Message.new('/goto/8bar', gridnr)
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
    Dir["#{dir}/[0-3].wav"].each_with_index do |st,i|

      img = st.sub('wav','png')
      unless (File.exists?(img) and FileUtils.uptodate?(img,[st]))
        `ffmpeg -y -i "#{st}" -filter_complex 'showwavespic=s=#{w}x#{h/4}:colors=white[a];color=s=#{w}x#{h/4}:color=black[b];[b][a]overlay'  -frames:v 1 "#{img}"`
      end
      stems[i] = Image.new(0,i*h/4,img)
      stems[i].width = w
      stems[i].height = h/4
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
  when 'space'
    client.send Message.new('/stop')
    #client.send Message.new('/goto/8bar', 0)
  else
    p event.key
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
