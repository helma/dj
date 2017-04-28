#!/usr/bin/env ruby

  `killall chuck`
  `killall jackd`
  #`killall ruby`
#begin
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

jack = nil
["UDAC8", "USBStreamer","CODEC","PCH"].each do |d|
  if `aplay -l |grep card`.match(d)
    jack = spawn "jackd -d alsa -P hw:#{d} -r 44100"
    Process.detach jack
    sleep 1
    break
  end
end

#chuck = spawn "chuck $HOME/music/src/dj/chuck/deck.ck" 
chuck = spawn "chuck deck.ck" 
Process.detach chuck

tracks = File.readlines(ARGV[0]).collect{|f| f.chomp} if File.exists? ARGV[0]
oscclient = OSC::Client.new 9668
midiin = UniMIDI::Input.find{ |device| device.name.match(/Launchpad/) }.open
midiout = UniMIDI::Output.find{ |device| device.name.match(/Launchpad/) }.open

quant = true
bpm = 132.0
eightbars = 0
bars = 0
sixteenth = 0
led_16th = 0
led_bars = 0
led_8bars = 0
nr_8bars = 0
midiout.puts(176,0,0)  # reset

osc = fork do
  OSC.run do

    oscserver = Server.new 9669
    last16th = 0
    lastbar = 0
    last8 = 0

    oscserver.add_pattern "/sixteenth" do |*args| 
      sixteenth = args[1]
      led_16th = sixteenth % 16
      led_16th > 7 ? led_16th += 112-8 : led_16th += 96
      midiout.puts(144,last16th,OFF) if last16th != led_16th
      midiout.puts(144,led_16th,GREEN_FULL)
      last16th = led_16th

      if (sixteenth % 16) == 0
        bars = sixteenth/16
        led_bars = bars % 8 + 80
        midiout.puts(144,lastbar,OFF) if lastbar != led_bars
        midiout.puts(144,led_bars,GREEN_FULL)
        lastbar = led_bars
      end

      if (bars % 8) == 0
        eightbars = bars/8
        col = eightbars % 8
        row = eightbars / 8
        led_8bars = col+16*row
        if eightbars <= nr_8bars
          midiout.puts(144,last8,AMBER_LOW) if last8 != led_8bars
          midiout.puts(144,led_8bars,GREEN_FULL)
        end
        last8 = led_8bars
      end
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
          q = 0
          if row < 4 # eightbars
            q = 16*8 if quant
            pos = (row*8+col)*8*16
          elsif row == 6 # bars
            q = 16 if quant
            pos = col*8
          else # 16th
            q = 1 if quant
            pos = 8*(row-7)+col
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
        oscclient.send(OSC::Message.new("/read", file)) if file
        (104..111).each {|n| midiout.puts(176,n,OFF) }
        midiout.puts(176,d[1],GREEN_FULL)
      end
    end
  end
end

=begin
rescue StandardError => e
  p "EXIT"
  p e.inspect
  #deck.midiout.puts(176,0,0)  # reset
  `killall chuck`
  `killall jackd`
  `killall ruby`
end
=end
