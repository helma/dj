#!/usr/bin/env ruby
require_relative 'setup.rb'
require 'highline/import'

@pool = [[],[],[],[]]

all_files = @scenes.flatten.compact.collect{|f| f.file}

Dir[File.join(@dir,"**","*wav")].each do |file|
  unless all_files.include? file
    sample = Sample.new file
    sample.review
    if sample.type == "drums"
      if sample.energy == "high"
        @pool[0] << sample
      elsif sample.energy == "low"
        @pool[1] << sample
      end
    elsif sample.type == "music"
      if sample.energy == "high"
        @pool[2] << sample
      elsif sample.energy == "low"
        @pool[3] << sample
      end
    end
  end
end

#@pool.each { |p| p.shuffle! }
@pool[0] += @pool[1]
@pool[1] += @pool[0]
@pool[2] += @pool[3]
@pool[3] += @pool[2]

@mutes = [false,false,false,false]

def pool 
  (4..7).each do |row|
    row -= 4
    (0..7).each do |col|
      c = 8*@bank + col
      if @pool[row][c]
        sample = @pool[row][c]
        if @current[row] == @pool[row][c]
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
  end
end
pool

def mutes
  (0..3).each do |row|
    @mutes[row] ?  @midiout.puts(144,(row+4)*16+8,RED_FULL) : @midiout.puts(144,(row+4)*16+8,OFF) # mutes E-H
  end
end

def save_scene i
  (0..3).each do |track|
    @scenes[track][i] = @current[track]
    (0..3).each do |t|
      @pool[t].delete @current[track]
    end
  end
  File.open(ARGV[0],"w+"){|f| Marshal.dump @scenes, f}
end

def play_scene row, col
  @scenes[row][col] and !@mutes[col] ? @oscclient.send(OSC::Message.new("/#{row}/read", @scenes[row][col].file)) : @oscclient.send(OSC::Message.new("/#{row}/mute"))
  @current[row] = @scenes[row][col]
end

def play_pool row, col
  @pool[row][col] and !@mutes[col] ? @oscclient.send(OSC::Message.new("/#{row}/read", @pool[row][col].file)) : @oscclient.send(OSC::Message.new("/#{row}/mute"))
  @current[row] = @pool[row][col]
end

while true do
  @midiin.gets.each do |m|
    d = m[:data]
    col = d[1] % 16
    row = d[1] / 16
    if d[0] == 144 # notes
      if col < 8 # grid
        if d[2] == 127 # press
          @del_time = Time.now
        elsif d[2] == 0 # release
          if row < 4 # scenes
            c = 8*@bank + col
            if Time.now - @del_time > 1 # long press
              @scenes[row][c].delete # delete
              @scenes[row][c] = nil
              @oscclient.send OSC::Message.new("/#{row}/mute") # stop playback
            else # short press
              play_scene row, c
            end
          elsif row < 8 # pool
            row -= 4
            if Time.now - @del_time > 1 # long press
              @pool[row][col].delete # delete
              @pool[row].delete_at col
              @oscclient.send OSC::Message.new("/#{row}/mute") # stop playback
            else # short press
              play_pool row, col
            end
          end
        end
      elsif col == 8 and d[2] == 127 # A-H press
      #else
        if row < 4 # A-D choose bank
          @bank = row
        elsif row < 8 # E-F mute track
          row -= 4
          @mutes[row] ? @mutes[row] = false : @mutes[row] = true
          @mutes[row] ? @oscclient.send(OSC::Message.new("/#{row}/mute")) : @oscclient.send(OSC::Message.new("/#{row}/unmute"))
        end
      end
    elsif d[0] == 176 # 1-8 scenes
      col = d[1] - 104
      c = 8*@bank + col
      if d[2] == 127 # press
        @save_time = Time.now
        if @last_scene # move scene
          (0..3).each do |row|
            src = @scenes[row].delete_at @last_scene
            @scenes[row].insert c, src
            play_scene row, c
          end
          @last_scene = nil
        else
          @last_scene = col
        end
      elsif d[2] == 0 # release
        if Time.now - @save_time > 1
          save_scene c
        else
          (0..3).each { |row| play_scene row, c } if @last_scene
        end
        @last_scene = nil
      end
    end
    scenes
    pool
    mutes
  end
end
=begin
=end
