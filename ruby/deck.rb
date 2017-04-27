#!/usr/bin/env ruby

  `killall chuck`
  `killall jackd`
  #`killall ruby`
begin
require "ruby-osc"
require "unimidi"

include OSC

# launchpad colors
OFF = 12
RED_LOW = 13
RED_FULL = 15
RED_FLASH = 11
AMBER_LOW = 29
AMBER_FULL = 63
AMBER_FLASH = 59
YELLOW_FULL = 62
YELLOW_FLASH = 58
GREEN_LOW = 28
GREEN_FULL = 60
GREEN_FLASH = 56

["UDAC8", "USBStreamer","CODEC","PCH"].each do |d|
  if `aplay -l |grep card`.match(d)
    jack = spawn "jackd -d alsa -P hw:#{d} -r 44100"
    Process.detach jack
    sleep 1
    chuck = spawn "chuck $HOME/music/src/dj/chuck/clock.ck $HOME/music/src/dj/chuck/deck.ck" 
    Process.detach chuck
    break
  end
end

tracks = File.readlines(ARGV[0]).collect{|f| f.chomp} if File.exists? ARGV[0]
oscclient = OSC::Client.new 9668
midiin = UniMIDI::Input.find{ |device| device.name.match(/Launchpad/) }.open
midiout = UniMIDI::Output.find{ |device| device.name.match(/Launchpad/) }.open

quant = true
bpm = 132.0
eightbars = 0
bars = 0
sixteenth = 0
midiout.puts(176,0,0)  # reset

fork do
  OSC.run do
    oscserver = Server.new 9669

    last16th = nil
    oscserver.add_pattern "/sixteenth" do |*args| 
      midiout.puts(144,last16th,OFF) if last16th
      sixteenth = args[1]
      note = args[1] % 16
      note > 7 ? note += 112-8 : note += 96
      midiout.puts(144,note,GREEN_FULL)
      last16th = note
    end

    lastbar = nil
    oscserver.add_pattern "/bars" do |*args| 
      bars = args[1]
      note = args[1] % 8 + 80
      #p bars, note
      midiout.puts(144,note,GREEN_FULL)
      midiout.puts(144,lastbar,OFF) if lastbar and lastbar != note
      lastbar = note
    end

    last8 = nil
    oscserver.add_pattern "/eightbars" do |*args| 
      eightbars = args[1]
      col = args[1] % 8
      row = args[1] / 8
      note = col+16*row
      p eightbars, note
      midiout.puts(144,note,GREEN_FULL)
      midiout.puts(144,last8,AMBER_LOW) if last8 and last8 != note
      last8 = note
    end

  end
end

while true do
  midiin.gets.each do |m|
    d = m[:data]
    if d[0] == 144
      col = d[1] % 16
      row = d[1] / 16
      if col < 8 # grid
        if d[2] == 127 # press
          q = ""
          if row < 4 # eightbars
            q = "eightbars" if quant
            pos = (row*8+col)*8*240.0/bpm
          elsif row == 6 # bars
            q = "bars" if quant
            pos = eightbars*8*240.0/bpm
            pos += col*240.0/bpm
          else # 16th
            q = "sixteenth" if quant
            pos = eightbars*8*240.0/bpm + bars*240.0/bpm
            pos += col*16.0/bpm
          end
          oscclient.send(OSC::Message.new("/play",pos,q))
        end
      elsif col == 8 
        if row == 0 # A
          if d[2] == 127
            quant = false
          elsif d[2] == 0
            quant = true
          end
        elsif row == 1 # B
          oscclient.send OSC::Message.new("/rate", 1.04) if d[2] == 127 # speedup
          oscclient.send OSC::Message.new("/rate", 1.0) if d[2] == 0 # original bpm
        elsif row == 2 # C
          oscclient.send OSC::Message.new("/rate", 0.96) if d[2] == 127 # slowdown
          oscclient.send OSC::Message.new("/rate", 1.0) if d[2] == 0 # original bpm
        end
      end
    elsif d[0] == 176 and d[2] == 127 # 1-8 press
      col = d[1] - 104
      file = tracks[col]
      if file
        stat = Hash[`sox "#{file}" -n stat 2>&1|sed '/Try/,$d'`.split("\n")[0..14].collect{|l| l.split(":").collect{|i| i.strip}}]
        nr_8bars = (stat["Length (seconds)"].to_f*bpm/(8*240)).round
        n = 0
        (0..3).each do |r|
          (0..7).each do |c| 
            n <= nr_8bars ? midiout.puts(144,r*16+c,AMBER_LOW) : midiout.puts(144,r*16+c,OFF) 
            n += 1
          end
        end
        midiout.puts(144,0,GREEN_FULL)
        oscclient.send(OSC::Message.new("/read", file)) if file
        (104..111).each {|n| midiout.puts(176,n,OFF) }
        midiout.puts(176,d[1],GREEN_FULL)
      end
    end
  end
end

rescue StandardError => e
  p "EXIT"
  p e.inspect
  #deck.midiout.puts(176,0,0)  # reset
  `killall chuck`
  `killall jackd`
  `killall ruby`
end
