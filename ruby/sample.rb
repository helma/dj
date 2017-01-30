#!/bin/env ruby
require 'fileutils'
require 'matrix'
require 'digest/md5'
require 'yaml'

class Sample 

  attr_accessor :file, :name, :bars, :mfcc, :dir, :seconds, :max_amplitude, :bpm, :onsets, :energy, :rhythm, :presence, :type

  def initialize file
    @file = file
    @dir = File.dirname(@file)
    @name = File.basename(file)
    @ext = File.extname file
    @json_file = file.sub @ext,".json"
    if File.exists? @json_file and File.mtime(@json_file) > File.mtime(file)
      metadata =  JSON.parse(File.read(@json_file))
      @bpm = metadata["bpm"]
      @seconds = metadata["seconds"]
      @max_amplitude = metadata["max_amplitude"]
      @bars = metadata["bars"]
      @type = metadata["type"]
      @energy = metadata["energy"] # up, down, constant, variable
      @rhythm = metadata["rhythm"] # straight, break
      @presence = metadata["presence"] # fg, bg
    else
      stat = Hash[`sox "#{@file}" -n stat 2>&1|sed '/Try/,$d'`.split("\n")[0..14].collect{|l| l.split(":").collect{|i| i.strip}}]
      @bpm = @file.match(/\d\d\d/).to_s.to_i
      @bpm = 132
      @seconds = stat["Length (seconds)"].to_f
      @max_amplitude = [stat["Maximum amplitude"].to_f,stat["Minimum amplitude"].to_f.abs].max
      @bars = @seconds*@bpm/60/4.0
    end
    @mfcc_file = file.sub @ext,".mfcc"
    if File.exists? @mfcc_file and File.mtime(@mfcc_file) > File.mtime(file)
      @mfcc =  Marshal.load(File.read(@mfcc_file))
    else
      # remove first column with timestamps
      # remove second column with energy
      @mfcc = Vector.elements(`aubiomfcc "#{@file}"`.split("\n").collect{|l| l.split(" ")[2,12].collect{|i| i.to_f}}.flatten)
    end
    @onsets_file = file.sub @ext,".onsets"
    if File.exists? @onsets_file and File.mtime(@onsets_file) > File.mtime(file)
      @onsets =  JSON.parse(File.read(@onsets_file))
    else
      @onsets = `aubioonset "#{@file}"`.split("\n").collect{|t| t.to_f}
    end
    save
  end

  def save
    File.open(@json_file,"w+") do |f|
      meta = {
        :bpm => @bpm,
        :seconds => @seconds,
        :max_amplitude => @max_amplitude,
        :bars => @bars,
        :type => @type,
        :energy => @energy,
        :rhythm => @rhythm,
        :presence => @presence,
      }
      f.puts meta.to_json
    end
    File.open(@mfcc_file,"w+") { |f| Marshal.dump @mfcc, f }
    File.open(@onsets_file,"w+") { |f| f.puts @onsets.to_json }
  end

  def delete
    puts `trash "#{@json_file}"`
    puts `trash "#{@mfcc_file}"`
    puts `trash "#{@onsets_file}"`
    puts `trash "#{@file}"`
  end

  def png
    ext = File.extname @file
    img = file.sub ext,".png"
    unless File.exists? img and File.mtime(img) > File.mtime(@file)
      `ffmpeg -i "#{@file}" -filter_complex "showwavespic=s=1918x1078:split_channels=1:colors=white[a];color=s=1918x1078:color=black[b];[b][a]overlay"  -frames:v 1 "#{img}"`
    end
    img
  end

  def display
    `w3m #{png}`
  end

  def backup 
    bakdir = File.join "/tmp/ot", @dir, "bak"
    date = `date +\"%Y%m%d_%H%M%S\"`.chomp
    bakfile = File.join bakdir, name+"."+date
    FileUtils.mkdir_p bakdir
    FileUtils.cp @file, bakfile
    bakfile
  end

  def md5
    Digest::MD5.file(@file).to_s
  end

  def pitch
    input = `aubionotes -v -u midi  -i #{@file} 2>&1 |grep "^[0-9][0-9].000000"|sed 's/read.*$//'`.split("\n")
    input.empty? ? nil : input.first.split("\t").first.to_i  # only onset pitch
  end

  def normalized?
    @max_amplitude > 0.95
  end

  def normalize
    unless normalized?
      puts "normalizing #{@file}"
      `sox -G --norm "#{backup}" "#{@file}"`
      stat = Hash[`sox "#{@file}" -n stat 2>&1|sed '/Try/,$d'`.split("\n")[0..14].collect{|l| l.split(":").collect{|i| i.strip}}]
      @max_amplitude = [stat["Maximum amplitude"].to_f,stat["Minimum amplitude"].to_f.abs].max
      save
    end
  end

=begin
  def zerocrossings
    snd = RubyAudio::Sound.open @file
    snd.seek 0
    buf = snd.read(:float, snd.info.frames)
    i = buf.size-2
    while i >= 0 and (buf[i][0]*buf[i+1][0] < 0 or buf[i][1]*buf[i+1][1] < 0) # get first zero crossing of both channels
      i-=1
    end
    puts i
  end
=end

  def similarity sample # cosine
    last = [@mfcc.size, sample.mfcc.size].min - 1
    v1 = Vector.elements(@mfcc[0..last])
    v2 = Vector.elements(sample.mfcc[0..last])
    v1.inner_product(v2)/(v1.magnitude*v2.magnitude)
  end

end
