#!/usr/bin/env ruby
require 'json'
require "unimidi"
require 'ruby-osc'
require_relative 'sample.rb'

@devices = ["UDAC8", "USBStreamer","CODEC","PCH"]

@devices.each do |d|
  if `aplay -l |grep card`.match(d)
    jack = spawn "jackd -d alsa -P hw:#{d} -r 44100"
    Process.detach jack
    sleep 1
    multichannel = 0
    multichannel = 1 if d == "USBStreamer" or d == "UDAC8"
    if multichannel == 1
      chuck = spawn "chuck --channels:8 $HOME/music/src/chuck/clock.ck $HOME/music/src/chuck/looper.ck $HOME/music/src/chuck/main.ck:#{multichannel} "
    else
      chuck = spawn "chuck $HOME/music/src/chuck/clock.ck $HOME/music/src/chuck/looper.ck $HOME/music/src/chuck/main.ck:#{multichannel} "
      
    end
    Process.detach chuck
    break
  end
end

@bpm = ARGV[0].match(/\d\d\d/).to_s.to_f
@midiin = UniMIDI::Input.find{ |device| device.name.match(/Launchpad/) }.open
@midiout = UniMIDI::Output.find{ |device| device.name.match(/Launchpad/) }.open
@oscclient = OSC::Client.new 9669

@current = [nil,nil,nil,nil]
@bank = 0

@dir = ARGV[0]
if File.exists? ARGV[0]
  @scenes = JSON.parse(File.read(File.join(@dir,"scenes.json"))).collect{|row| row.collect{|f| file = File.join(@dir,f); File.exists?(file) ? Sample.new(file) : nil}}
else
  @scenes = [[nil, nil, nil, nil, nil, nil, nil, nil], [nil, nil, nil, nil, nil, nil, nil, nil], [nil, nil, nil, nil, nil, nil, nil, nil], [nil, nil, nil, nil, nil, nil, nil, nil]]
end

@midiout.puts(176,0,0)
@midiout.puts(176,0,1)
@midiout.puts(176,0,40) # LED flashing

def scenes 
  (0..3).each do |row|
    (0..7).each do |col|
      c = 8*@bank + col
      sample = @scenes[row][c]
      if sample
        if @current[row] == sample
          if sample.rhythm == "straight"
            @midiout.puts(144,row*16+col,GREEN_FLASH)
          elsif sample.rhythm == "break"
            @midiout.puts(144,row*16+col,RED_FLASH)
          end
        else
          @midiout.puts(144,row*16+col,sample.color)
        end
      else
        @midiout.puts(144,row*16+col,OFF)
      end
    end
    @bank == row ? @midiout.puts(144,row*16+8,GREEN_FULL) : @midiout.puts(144,row*16+8,OFF) # bank A-D
  end
end

scenes

at_exit do
  `killall chuck`
  @midiout.puts(176,0,0)
  `killall jackd`
end
