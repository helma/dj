#!/usr/bin/env ruby
require 'json'
require "unimidi"
require 'ruby-osc'
require_relative 'loop.rb'

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
@scenes = JSON.parse(File.read(File.join(@dir,"scenes.json"))).collect{|row| row.collect{|f| file = File.join(@dir,f); File.exists?(file) ? file : nil}}

# TODO add metadata
@meta = @scenes.collect do |row| 
  row.collect do |f|
    if f
      ext = File.extname f
      json_file = f.sub ext, ".json"
      JSON.parse(File.read(json_file))
    end
  end
end

@offsets = [0,0,0,0]

@off = 12
@red_low = 13
@red_full = 15
@red_flash = 11
@amber_low = 29
@amber_full = 63
@amber_flash = 59
@yellow_full = 62
@yellow_flash = 58
@green_low = 28
@green_full = 60
@green_flash = 56

@midiout.puts(176,0,40) # LED flashing

def status 
  (0..3).each do |row|
    (0..7).each do |col|
      c = 8*@bank + col
      if @scenes[row][c]
        if @current[row] == @scenes[row][c]
          if @meta[row][c]["rhythm"] == "straight"
            @midiout.puts(144,row*16+col,@green_flash)
          elsif @meta[row][c]["rhythm"] == "break"
            @midiout.puts(144,row*16+col,@red_flash)
          end
        else
          if @meta[row][c]["rhythm"] == "straight"
            if @meta[row][c]["presence"] == "foreground"
              @midiout.puts(144,row*16+col,@green_full)
            elsif @meta[row][c]["presence"] == "background"
              @midiout.puts(144,row*16+col,@green_low)
            end
          elsif @meta[row][c]["rhythm"] == "break"
            if @meta[row][c]["presence"] == "foreground"
              @midiout.puts(144,row*16+col,@red_full)
            elsif @meta[row][c]["presence"] == "background"
              @midiout.puts(144,row*16+col,@red_low)
            end
          end
        end
      else
        @midiout.puts(144,row*16+col,@off)
      end
      if @offsets[row] == col
        @midiout.puts(144,(row+4)*16+col,@red_full)
      else
        @midiout.puts(144,(row+4)*16+col,@off)
      end
    end
    @bank == row ? @midiout.puts(144,row*16+8,@green_full) : @midiout.puts(144,row*16+8,@off) # bank A-D
  end
end

status

at_exit do
  `killall chuck`
  @midiout.puts(176,0,0)
  `killall jackd`
end
