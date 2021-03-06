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
    @cursor = Rectangle.new(0, y, WIDTH, height, [0,0,0,0])
    @loop = Rectangle.new(0, y, 0, height, [0.3,0.3,0.3,0.5])
    @phase = Rectangle.new(0, y, 2, height, "green")
    @next = Rectangle.new(0, y, gridwidth, height, [0,0,0,0])
  end

  def y
    @nr*HEIGHT/4
  end

  def height
    HEIGHT/4
  end

  def gridwidth
    WIDTH*EIGHTBAR_SAMPLES/@samples
  end

  def phase= s
    @phase.x = s*WIDTH
  end

  def loopstart i
    @loop.x = i*gridwidth
  end

  def loopend i
    @loop.width = i*gridwidth - @loop.x
  end

  def loop status
    status == 1 ? @loop.color = [0.5,0.2,0.2,0.5] : @loop.color = [0.3,0.3,0.3,0.5]
  end

  def select on
    on ? @cursor.color = [0,0,0,0] : @cursor.color = [0.5,0.5,0.5,0.5]
  end

  def next i
    @next.x = i*gridwidth
    @next.color = [0.2,0.3,0.2,0.5]
  end

  def next_off
    @next.x = 0
    @next.color = [0,0,0,0]
  end

end

@stems = []

def read_files
  #@@client.send Message.new('/stop')
  clear
  @stems = []
  dir = `ls -d ~/music/live/dj/* | dmenu -l 20`.chomp
  Dir["#{dir}/[0-3].wav"].each_with_index do |wav,i|
    @stems << Stem.new(wav, i) if File.exists?(wav)
  end
  samples = @stems.collect {|s| s.samples}.max
  pos = 0
  grid = []
  while (pos <= WIDTH) do
    grid << pos
    if (grid.size-1) % 8 == 0
      Rectangle.new(pos, 0, 2, HEIGHT, [1,1,1,1])
    elsif (grid.size-1) % 4 == 0 
      Rectangle.new(pos, 0, 1, HEIGHT, [1,1,1,0.5]) 
    else
      Rectangle.new(pos, 0, 1, HEIGHT, [0.5,0.5,0.5,0.5])
    end
    pos += WIDTH*EIGHTBAR_SAMPLES/samples
  end
  txt = Text.new(4, 0, dir.split('/').last, 20, 'vera.ttf')
end

on :key_down do |event|
  case event.key
  when 'escape'
    @@client.send Message.new('/stop')
  when 'q'
    @@client.send Message.new('/stop')
    close
  when 'a'
    read_files
  end
end

thr = Thread.new do
  OSC.run do
    server = Server.new 9090
    server.add_pattern "/phase" do |*args|
      @stems[args[1]].phase = args[2] if @stems[args[1]]
    end
    server.add_pattern "/loop" do |*args|
      @stems[args[1]].loop args[2]
    end
    server.add_pattern "/loop/in" do |*args|
      @stems[args[1]].loopstart args[2]
    end
    server.add_pattern "/loop/out" do |*args|
      @stems[args[1]].loopend args[2]
    end
    server.add_pattern "/select" do |*args|
      p args
      @stems[args[1]].select true
      (@stems-[@stems[args[1]]]).each{|s| s.select false}
    end
    server.add_pattern "/select/all" do |*args|
      @stems.each{|s| s.select true}
    end
    server.add_pattern "/next" do |*args|
      @stems[args[1]].next args[2]
    end
    server.add_pattern "/next/off" do |*args|
      @stems[args[1]].next_off 
    end
  end
end

read_files
show
