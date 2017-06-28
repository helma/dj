#!/usr/bin/env ruby

`chuck --kill`
`jack_control stop`
launchpad = `chuck --probe 2>&1 |grep Launchpad|sed -n '1p'`.split(":")[1].strip.gsub(/[\[\]]/,'')

["UDAC8", "USBStreamer","CODEC","PCH"].each do |d|
  if `aplay -l |grep card`.match(d)
    `jack_control ds alsa`
    `jack_control dps device hw:#{d}`
    `jack_control start`
    sleep 1
    if d == "USBStreamer" or d == "UDAC8"
      chuck = spawn "chuck --channels:8 deck.ck:#{launchpad}"
    else
      chuck = spawn "chuck deck.ck:#{launchpad}"
    end
    Process.detach chuck
    break
  end
end

load "./display.rb"

at_exit do
  `chuck --kill`
  `jack_control stop`
end
