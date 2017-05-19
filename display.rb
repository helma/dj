#!/usr/bin/env ruby
require 'ruby-osc'
require 'ruby2d'

w = 1920
h = 1080
set width: w
set height: h
set fullscreen: true

=begin
waveforms = []
Dir["/home/ch/music/live/dj/0/0/[0-3].wav"].each do |f|
  waveforms << f.sub('wav','png')
  #`ffmpeg -i "#{f}" -filter_complex 'showwavespic=s=#{w}x#{4*h}:split_channels=1:colors=white[a];color=s=#{w}x#{4*h}:color=black[b];[b][a]overlay'  -frames:v 1 "#{waveforms.last}"`
  #`ffmpeg -i "#{f}" -filter_complex 'showwavespic=s=#{w}x#{h/4}:colors=white[a];color=s=#{w}x#{h/4}:color=black[b];[b][a]overlay'  -frames:v 1 "#{waveforms.last}"`
end
waveforms.each_with_index do |img,i|
  stem = Image.new(0,i*h/4,img)
  stem.width = w
  stem.height = h/4
end
=end

looprange = Rectangle.new(0, 0, 0, h, [0,1,0,0.5])
@cursor = Rectangle.new(0, 0, 1, h, "red")

tick = 0

on key: 'escape' do
  close
end

include OSC
thr = Thread.new do
  OSC.run do
    server = Server.new 9090

    server.add_pattern "/load" do |*args|
      bank = args[1]
      track = args[2]
      Dir["/home/ch/music/live/dj/#{args[1]}/#{args[2]}/[0-3].wav"].each_with_index do |st,i|
        img = st.sub('wav','png')
        unless File.exists?(img) 
          `ffmpeg -i "#{st}" -filter_complex 'showwavespic=s=#{w}x#{h/4}:colors=white[a];color=s=#{w}x#{h/4}:color=black[b];[b][a]overlay'  -frames:v 1 "#{img}"`
        end
        stem = Image.new(0,i*h/4,img)
        stem.width = w
        stem.height = h/4
      end
      @cursor = Rectangle.new(0, 0, 1, h, "red")
    end

    server.add_pattern "/phase" do |*args|
      p args[1]*w
      @cursor.x = args[1]*w
    end

    server.add_pattern "/exit" do |*args|    # this will just match /exit address
      exit
    end
  end
end

show
