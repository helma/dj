#!/usr/bin/env ruby
require "ruby-osc"
require "unimidi"

class Deck
  include OSC


  def initialize playlist
    @oscclient = OSC::Client.new 9668
    @midiin = UniMIDI::Input.find{ |device| device.name.match(/Launchpad/) }.open
    @midiout = UniMIDI::Output.find{ |device| device.name.match(/Launchpad/) }.open

    @tracks = [nil, nil, nil, nil, nil, nil, nil, nil]
    @quant = false
    @bpm = 132.0
    @eightbars = 0
    @bars = 0
    @sixteenth = 0
    @@tracks = File.readlines(playlist).collect{|f| f.chomp} if File.exists? playlist
    @midiout.puts(176,0,0)  # reset
  end

  def clock
    OSC.run do
    @@oscserver = Server.new 9669

      last16th = nil
      @@oscserver.add_pattern "/sixteenth" do |*args| 
        @midiout.puts(144,last16th,12) if last16th
        @sixteenth = args[1]
        note = args[1] % 16
        note > 7 ? note += 112-8 : note += 96
        @midiout.puts(144,note,60)
        last16th = note
      end

      lastbar = nil
      @@oscserver.add_pattern "/bars" do |*args| 
        @bars = args[1]
        note = args[1] % 8 + 80
        @midiout.puts(144,note,60)
        @midiout.puts(144,lastbar,12) if lastbar
        lastbar = note
      end

      last8 = nil
      @@oscserver.add_pattern "/eightbars" do |*args| 
        @eightbars = args[1]
        note = args[1] 
        col = args[1] % 8
        row = args[1] / 8
        note = col+16*row
        @midiout.puts(144,note,60)
        @midiout.puts(144,last8,12) if last8
        last8 = note
      end

    end
  end

  def run 
    while true do
      @midiin.gets.each do |m|
        d = m[:data]
        col = d[1] % 16
        row = d[1] / 16
        if d[0] == 144 and d[2] == 127 and col < 8 # grid
          q = ""
          if row < 4 # eightbars
            q = "eightbars" if @quant
            pos = (row*8+col)*8*240.0/bpm
          elsif row == 6 # bars
            q = "bars" if @quant
            pos = @eightbars*8*240.0/bpm
            pos += col*240.0/bpm
          else # 16th
            q = "sixteenth" if @quant
            pos = @eightbars*8*240.0/bpm + @bars*240.0/bpm
            pos += col*16.0/bpm
          end
          @oscclient.send(OSC::Message.new("/play",pos,q))
        elsif col == 8
          if row == 0 # A
            if d[2] == 127
              @quant = false
              @midiout.puts(176,d[1],13)
            elsif d[2] == 0
              @quant = true
              @midiout.puts(176,d[1],12)
            end
          elsif row == 1 # B
            @oscclient.send OSC::Message.new("/rate", 1.04) # speedup
          elsif row == 2 # C
            @oscclient.send OSC::Message.new("/rate", 0.96) # slowdown
          end
        elsif d[0] == 176 and d[2] == 127 # 1-8 press
          col = d[1] - 104
          file = @tracks[col]
          @oscclient.send(OSC::Message.new("/read", file)) if file
          (104..111).each {|n| @midiout.puts(176,n,12) }
          @midiout.puts(176,d[1],60)
        end
      end
    end
  end
end


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

deck = Deck.new ARGV[0]
fork { deck.clock }
deck.run

at_exit do
  deck.midiout.puts(176,0,0)  # reset
  `killall chuck`
  `killall jackd`
end
