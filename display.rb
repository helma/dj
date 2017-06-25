#!/usr/bin/env ruby
require 'fileutils'
require 'ruby-osc'
require 'ruby2d'

include OSC
@@client = Client.new 9091

BPM = 132.0
EIGHTBAR_SAMPLES = 44100 * 8 * 8 * 30/BPM

WIDTH = 1920
HEIGHT = 1080
set width: WIDTH
set height: HEIGHT

class Stem

  attr_reader :samples

  def initialize wav, nr
    @file = wav
    @nr = nr
    @@client.send(Message.new("/read",@nr,@file))
    img = wav.sub('wav','png')
    unless (File.exists?(img) and FileUtils.uptodate?(img,[wav]))
      `ffmpeg -y -i "#{wav}" -filter_complex 'showwavespic=s=#{WIDTH}x#{height}:colors=white[a];color=s=#{WIDTH}x#{height}:color=black[b];[b][a]overlay'  -frames:v 1 "#{img}"`
    end
    @image = Image.new(0,y,img)
    @image.width = WIDTH
    @image.height = HEIGHT/4
    @samples = `soxi "#{@file}" |grep Duration|cut -d '=' -f2|sed  's/samples//'|tr -d " "`.to_i
    @phase = Rectangle.new(0, y, 1, height, "green")
    @cursor = Rectangle.new(0, y, WIDTH*EIGHTBAR_SAMPLES/@samples, height, [0.5,0.5,0.5,0.5])
    @loop = Rectangle.new(0, y, 0, height, [0.3,0.3,0.3,0.5])
    @select_loop = false
  end

  def y
    @nr*HEIGHT/4
  end

  def height
    HEIGHT/4
  end

  def toggle_loop
    @@client.send(Message.new("/loop/toggle",@nr))
  end

  def goto_8bar_quant gridnr
    @@client.send Message.new('/goto/8bar/quant', @nr, gridnr)
  end
  
  def goto_8bar_now gridnr
    @@client.send Message.new('/goto/8bar/now', @nr, gridnr)
  end
  
  def goto_8bar_next gridnr
    @@client.send Message.new('/goto/8bar/next', @nr, gridnr)
  end

  def phase= s
    @phase.x = s*WIDTH
  end

  def loop= status
    status == 1 ? @loop.color = [0.5,0.2,0.2,0.5] : @loop.color = [0.3,0.3,0.3,0.5]
  end

  def loop_in= start
    @select_loop = true
    @loop.x = start
  end

  def loop_out= out
    @@client.send Message.new('/loop/set/8bar', loop_in, loop_out)
    @select_loop = false
  end

  def cursor= s
    @cursor.x = s
  end

  def cursor_off
    @cursor.color = [0,0,0,0]
  end

  def cursor_on
    #@cursor.width = WIDTH*EIGHTBAR_SAMPLES/@samples
    @cursor.color = [0.5,0.5,0.5,0.5]
  end

end

singlestem = false
stems = []
grid = []
selected_stems = []
gridnr = 0

on :mouse_move do |event|
  singlestem ? selected_stems = [stems[(4*event.y/HEIGHT).floor]] : selected_stems =  stems
  gridnr = grid.index( grid.select{|g| event.x < g}.first)
  gridnr = grid.size unless gridnr
  gridnr -= 1
  selected_stems.each {|s| s.cursor = grid[gridnr]}
  stems.each{|s| s.cursor_off if s} if singlestem
  selected_stems.each{|s| s.cursor_on if s}
end

on :mouse_down do |event|
  case event.button
  when :left
    selected_stems.each {|s| s.goto_8bar_quant gridnr }
  when :right
    selected_stems.each {|s| s.goto_8bar_now gridnr }
  end
end

on :key_down do |event|
  case event.key
  when 'escape'
    @@client.send Message.new('/stop')
  when 'q'
    @@client.send Message.new('/stop')
    close
  when 'a'
    dir = `ls -d ~/music/live/dj/* | dmenu -l 20`.chomp
    clear
    Dir["#{dir}/[0-3].wav"].each_with_index do |wav,i|
      if File.exists?(wav)
        @@client.send Message.new('/load', dir)
        stems << Stem.new(wav, i)
      end
    end
    samples = stems.collect {|s| s.samples}.max
    pos = 0
    grid = []
    while (pos <= WIDTH) do
      grid << pos
      grid.size % 4 == 0 ? Rectangle.new(pos, 0, 1, HEIGHT, [1,1,1,0.5]) : Rectangle.new(pos, 0, 1, HEIGHT, [0.5,0.5,0.5,0.5])
      pos += WIDTH*EIGHTBAR_SAMPLES/samples
    end
    gridnr = 0
    txt = Text.new(4, 0, dir.split('/').last, 20, 'vera.ttf')
  when '/'
    selected_stems.each {|s| s.toggle_loop }
  when "left shift"
    selected_stems.each {|s| s.loop_in = grid[gridnr] }
  when "left ctrl"
    stems.each{|s| s.cursor_off if s}
    singlestem = true
    #p selected_stems.size
    selected_stems.each{|s| s.cursor_on if s}
  when 'space'
    selected_stems.each {|s| s.goto_8bar_next gridnr}
  when 'right'
    @@client.send Message.new('/speed/up')
  when 'left'
    @@client.send Message.new('/speed/down')
  else
    p event.key
  end
end

on :key_up do |event|
  case event.key
  when "left shift"
    selected_stems.each {|s| s.loop_out = grid[gridnr]+1 }
  when "left ctrl"
    singlestem = false
    #stems.each{|s| s.cursor_on if s}
  when 'right'
    @@client.send Message.new('/speed/normal')
  when 'left'
    @@client.send Message.new('/speed/normal')
  end
end

thr = Thread.new do
  OSC.run do
    server = Server.new 9090
    server.add_pattern "/phase" do |*args|
      stems[args[1]].phase = args[2] if stems[args[1]]
    end
    server.add_pattern "/loop" do |*args|
      stems[args[1]].loop args[2]
    end
    server.add_pattern "/loop/start" do |*args|
      stems[args[1]].loopstart args[2]
    end
  end
end

show
