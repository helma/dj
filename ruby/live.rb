#!/usr/bin/env ruby
require_relative 'setup.rb'

@offsets = [0,0,0,0]

def offsets
  (0..3).each do |row|
    (0..7).each do |col|
      if @offsets[row] == col
        @midiout.puts(144,(row+4)*16+col,RED_FULL)
      else
        @midiout.puts(144,(row+4)*16+col,OFF)
      end
    end
  end
end

while true do
  @midiin.gets.each do |m|
    d = m[:data]
    col = d[1] % 16
    row = d[1] / 16
    if d[0] == 144 and d[2] == 127
      if row < 4 and col < 8 # grid
        c = 8*@bank + col
        @scenes[row][c].play row if @scenes[row][c]
        #@oscclient.send OSC::Message.new("/#{row}/read", @scenes[row][c].file.to_s) if @scenes[row][c]
        @offsets[row] = 0
        @current[row] = @scenes[row][c]
      elsif row < 8 and col < 8 # offsets
        row -= 4
        @oscclient.send OSC::Message.new("/#{row}/offset", col)
        @offsets[row] = col
      elsif col == 8 # A-H
        if row < 4 # A-D choose bank
          @bank = row
        elsif row == 4 and col == 8 # E
          @oscclient.send OSC::Message.new("/rate", 1.04) # speedup
        elsif row == 5 and col == 8 # F
          @oscclient.send OSC::Message.new("/rate", 0.96) # slowdown
        elsif row == 6 and col == 8 # G
          @oscclient.send OSC::Message.new("/reset")
          (0..3).each{|t| @offsets[t] = 0 }
        elsif row == 7 and col == 8 # H
          @oscclient.send OSC::Message.new("/restart")
          @offsets[row] = 0
          (0..3).each{|t| @offsets[t] = 0 }
        end
      end
    elsif d[0] == 176 # 1-8
      col = 8*@bank + d[1] - 104
      (0..3).each do |row|
        @scenes[row][col].play row if @scenes[row][col]
        @offsets[row] = 0
        @current[row] = @scenes[row][col]
      end
    end
    scenes
    offsets
  end
end
