#!/usr/bin/env ruby
require 'ruby-osc'

["UDAC8", "USBStreamer","CODEC","PCH"].each do |d|
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

class Chuck

  @@oscclient = OSC::Client.new 9669

  def self.play sample, track=0
    @@oscclient.send(OSC::Message.new("/#{track}/read", sample.file))
  end

  def self.mute track=0
    @@oscclient.send(OSC::Message.new("/#{track}/mute"))
  end

  def self.unmute track=0
    @@oscclient.send(OSC::Message.new("/#{track}/unmute"))
  end

  def self.offset off, track=0
    @@oscclient.send OSC::Message.new("/#{track}/offset", off)
  end

  def self.speedup
    @@oscclient.send OSC::Message.new("/rate", 1.04) # speedup
  end

  def self.slowdown
    @@oscclient.send OSC::Message.new("/rate", 0.96) # slowdown
  end

  def self.reset
    @@oscclient.send OSC::Message.new("/reset")
  end

  def self.restart
    @@oscclient.send OSC::Message.new("/restart")
  end

end
