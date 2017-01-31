#!/usr/bin/env ruby
require_relative 'setup.rb'
require_relative 'sample.rb'

@dir = ARGV[0]
if File.exists? ARGV[0]
  @scenes = JSON.parse(File.read(File.join(@dir,"scenes.json"))).collect{|row| row.collect{|f| file = File.join(@dir,f); File.exists?(file) ? file : nil}}
else
  @scenes = [[nil, nil, nil, nil, nil, nil, nil, nil], [nil, nil, nil, nil, nil, nil, nil, nil], [nil, nil, nil, nil, nil, nil, nil, nil], [nil, nil, nil, nil, nil, nil, nil, nil]]
end

@pool = [[],[],[],[]]

Dir[File.join(@dir,"**","*wav")].collect{|f| Sample.new File.expand_path(f)}.each do |s|
  l = Loop.from_sample(s)
  unless @scenes.flatten.compact.collect{|f| f.file}.include? l.file
    if s.tags.include? "drums" and s.bars.round > 16
      @pool[0] << l
    elsif s.tags.include? "drums" and s.bars.round <= 16
      @pool[1] << l
    elsif s.tags.include? "music" and s.bars.round > 16
      @pool[2] << l
    elsif s.tags.include? "music" and s.bars.round <= 16
      @pool[3] << l
    end
  end
end

@pool.each { |p| p.shuffle! }
@pool[0] += @pool[1]
@pool[1] += @pool[0]
@pool[2] += @pool[3]
@pool[3] += @pool[2]

@mutes = [false,false,false,false]

def status 
  # scenes
  (0..3).each do |row|
    (0..7).each do |col|
      c = 8*@bank + col
      if @scenes[row][c]
        if @current[row] == @scenes[row][c] # playing
          if @scenes[row][c].bars.round <= 16
            @midiout.puts(144,row*16+col,28) # dimmed green
          else
            @midiout.puts(144,row*16+col,60) # bright green
          end
        else
          if @scenes[row][c].bars.round <= 16
            @midiout.puts(144,row*16+col,29)
          else
            @midiout.puts(144,row*16+col,63)
          end
        end
      else
        @midiout.puts(144,row*16+col,12)
      end
    end
    @bank == row ? @midiout.puts(144,row*16+8,60) : @midiout.puts(144,row*16+8,12) # bank A-D
    @mutes[row] ?  @midiout.puts(144,(row+4)*16+8,15) : @midiout.puts(144,(row+4)*16+8,12) # mutes E-H
  end
  # pool
  (4..7).each do |row|
    row -= 4
    (0..7).each do |col|
      if @pool[row][col]
        if @current[row] == @pool[row][col]
          if @pool[row][col].bars.round <= 16
            @midiout.puts(144,(row+4)*16+col,28)
          else
            @midiout.puts(144,(row+4)*16+col,60)
          end
        else
          if @pool[row][col].bars.round <= 16
            @midiout.puts(144,(row+4)*16+col,29)
          else
            @midiout.puts(144,(row+4)*16+col,63)
          end
        end
      else
        @midiout.puts(144,(row+4)*16+col,12)
      end
    end
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

status
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
    status
  end
end
