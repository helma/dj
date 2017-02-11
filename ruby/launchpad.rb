#!/usr/bin/env ruby
require 'json'
require "unimidi"
require_relative 'sample.rb'
require_relative 'chuck.rb'

module Launchpad
  class Common

      @@midiin = UniMIDI::Input.find{ |device| device.name.match(/Launchpad/) }.open
      @@midiout = UniMIDI::Output.find{ |device| device.name.match(/Launchpad/) }.open

      @@current = [nil,nil,nil,nil]
      @@bank = 0
      @@scenes = [[nil, nil, nil, nil, nil, nil, nil, nil], [nil, nil, nil, nil, nil, nil, nil, nil], [nil, nil, nil, nil, nil, nil, nil, nil], [nil, nil, nil, nil, nil, nil, nil, nil]]

    def self.run dir
      @@dir = dir

      @@scenes_file = File.join(@@dir,"scenes.json")
      if File.exists? @@scenes_file
        JSON.parse(File.read(@@scenes_file)).each_with_index do |row,i|
          row.each_with_index do |f,j|
            if f
              file = File.join(@@dir,f)
              @@scenes[i][j] = Sample.new(file) if File.exists?(file)
            end
          end
        end
      end

      @@midiout.puts(176,0,40) # LED flashing
    end

    def self.scenes 
      (0..3).each do |row|
        (0..7).each do |col|
          c = 8*@@bank + col
          sample = @@scenes[row][c]
          if sample
            if @@current[row] == sample
              if sample.rhythm == "straight"
                @@midiout.puts(144,row*16+col,GREEN_FLASH)
              elsif sample.rhythm == "break"
                @@midiout.puts(144,row*16+col,RED_FLASH)
              end
            else
              @@midiout.puts(144,row*16+col,sample.color)
            end
          else
            @@midiout.puts(144,row*16+col,OFF)
          end
        end
        @@bank == row ? @@midiout.puts(144,row*16+8,GREEN_FULL) : @@midiout.puts(144,row*16+8,OFF) # bank A-D
      end
    end

  end

  class Live < Common

    @@offsets = [0,0,0,0]

    def self.offsets
      (0..3).each do |row|
        (0..7).each do |col|
          if @@offsets[row] == col
            @@midiout.puts(144,(row+4)*16+col,RED_FULL)
          else
            @@midiout.puts(144,(row+4)*16+col,OFF)
          end
        end
      end
    end

    def self.run dir
      super dir
      while true do
        scenes
        offsets
        @@midiin.gets.each do |m|
          d = m[:data]
          col = d[1] % 16
          row = d[1] / 16
          if d[0] == 144 and d[2] == 127
            if row < 4 and col < 8 # grid
              c = 8*@@bank + col
              sample = @@scenes[row][c]
              Chuck.play sample, row if sample
              @@offsets[row] = 0
              @@current[row] = @@scenes[row][c]
            elsif row < 8 and col < 8 # offsets
              row -= 4
              Chuck.offset row, col
              @@offsets[row] = col
            elsif col == 8 # A-H
              if row < 4 # A-D choose bank
                @@bank = row
              elsif row == 4 and col == 8 # E
                Chuck.speedup
              elsif row == 5 and col == 8 # F
                Chuck.slowdown
              elsif row == 6 and col == 8 # G
                Chuck.reset
                (0..3).each{|t| @@offsets[t] = 0 }
              elsif row == 7 and col == 8 # H
                Chuck.restart
                @@offsets[row] = 0
                (0..3).each{|t| @@offsets[t] = 0 }
              end
            end
          elsif d[0] == 176 # 1-8
            col = 8*@@bank + d[1] - 104
            (0..3).each do |row|
              sample = @@scenes[row][col]
              Chuck.play sample, row if sample
              @@offsets[row] = 0
              @@current[row] = sample
            end
          end
        end
      end
    end
  end

  class Arrange < Common


    def self.pool 
      (4..7).each do |row|
        r = row - 4
        (0..7).each do |col|
          c = 8*@@bank + col
          sample = @@pool[r][c]
          if sample
            if @@current[r] == @@pool[r][c]
              if sample.rhythm == "straight"
                @@midiout.puts(144,row*16+col,GREEN_FLASH)
              elsif sample.rhythm == "break"
                @@midiout.puts(144,row*16+col,RED_FLASH)
              end
            else
              @@midiout.puts(144,row*16+col,sample.color)
            end
          else
            @@midiout.puts(144,row*16+col,OFF)
          end
        end
      end
    end

    def self.mutes
      (0..3).each do |row|
        @@mutes[row] ?  @@midiout.puts(144,(row+4)*16+8,RED_FULL) : @@midiout.puts(144,(row+4)*16+8,OFF) # mutes E-H
      end
    end

    def self.save_scene i
      # TODO add removd sampls from scenes to pool
      (0..3).each do |track|
        @@scenes[track][i] = @@current[track]
        (0..3).each do |t|
          @@pool[t].delete @@current[track]
        end
      end
      save
    end

    def self.save
      # TODO git
      File.open(@@scenes_file,"w+"){|f| f.puts @@scenes.collect{|r| r.collect{|s| s.name if s}}.to_json}
    end

    def self.run dir
      super dir
    @@pool = [[],[],[],[]]

    all_files = @@scenes.flatten.compact.collect{|f| f.file}

    drums = [[],[]]
    music = [[],[]]
    Dir[File.join(@@dir,"**","*wav")].each do |file|
      unless all_files.include? file
        sample = Sample.new file
        sample.review
        if sample.type == "drums"
          if sample.energy == "high"
            drums[0] << sample
          elsif sample.energy == "low"
            drums[1] << sample
          end
        elsif sample.type == "music"
          if sample.energy == "high"
            music[0] << sample
          elsif sample.energy == "low"
            music[1] << sample
          end
        end
      end
    end

    @@pool[0] = drums[0]+drums[1]
    @@pool[1] = drums[1]+drums[0]
    @@pool[2] = music[0]+music[1]
    @@pool[3] = music[1]+music[0]

    @@mutes = [false,false,false,false]
      @@last_scene = nil
      while true do
        scenes
        pool
        mutes
        @@midiin.gets.each do |m|
          d = m[:data]
          col = d[1] % 16
          row = d[1] / 16
          if d[0] == 144 # notes
            if col < 8 # grid
              if d[2] == 127 # press
                @@del_time = Time.now
              elsif d[2] == 0 # release
                if row < 4 # scenes
                  c = 8*@@bank + col
                  sample = @@scenes[row][c]
                  if sample
                    # TODO doubletap
                    if Time.now - @@del_time > 1 # long press
                      @@midiout.puts(144,row*16+c,AMBER_FULL)
                      sample.review!
                      if !File.exists? sample.file
                        @@scenes[row][c] = nil
                        @@current[row] = nil
                      end
                    else # short press
                      Chuck.play(sample,row) unless @@mutes[row]
                      @@current[row] = sample
                    end
                  else
                    Chuck.mute(row)
                    @@current[row] = nil
                  end
                elsif row < 8 # pool
                  row -= 4
                  c = 8*@@bank + col
                  sample = @@pool[row][c]
                  if sample
                    if Time.now - @@del_time > 1 # long press
                      @@midiout.puts(144,(row+4)*16+c,AMBER_FULL)
                      sample.review!
                      if !File.exists? sample.file
                        @@scenes[row][c] = nil
                        @@current[row] = nil
                      end
                    else # short press
                      Chuck.play(sample,row) unless @@mutes[row] 
                      @@current[row] = sample
                    end
                  else
                    Chuck.mute(row)
                    @@current[row] = nil
                  end
                end
              end
            elsif col == 8 and d[2] == 127 # A-H press
              if row < 4 # A-D choose bank
                @@bank = row
              elsif row < 8 # E-F mute track
                row -= 4
                @@mutes[row] ? @@mutes[row] = false : @@mutes[row] = true
                @@mutes[row] ? Chuck.mute(row) : Chuck.unmute(row)
              end
            end
          elsif d[0] == 176 # 1-8 scenes
            col = d[1] - 104
            c = 8*@@bank + col
            if d[2] == 127 # press
              @@save_time = Time.now
              if @@last_scene # move scene
                (0..3).each do |row|
                  src = @@scenes[row].delete_at @@last_scene
                  @@scenes[row].insert c, src
                end
                @@last_scene = nil
              else
                @@last_scene = col
              end
            elsif d[2] == 0 # release
              if Time.now - @@save_time > 1
                save_scene c
              else
                (0..3).each do |row|
                  sample = @@scenes[row][c]
                  Chuck.play sample, row if sample
                  @@current[row] = sample 
                end if @@last_scene
              end
              @@last_scene = nil
            end
          end
          save
        end
      end
    end
  end
end
