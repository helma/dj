#!/bin/env ruby
require 'json'
require 'ruby-osc'
require_relative 'sample.rb'
require 'highline/import'

jack = spawn "jackd -d alsa -P hw:PCH -r 44100"
Process.detach jack
sleep 1
chuck = spawn "chuck $HOME/music/src/chuck/play.ck"
Process.detach chuck
@oscclient = OSC::Client.new 9669

def play sample
  @oscclient.send OSC::Message.new("/play", sample.file)
end

def stop
  @oscclient.send OSC::Message.new("/stop")
end

at_exit do
  `killall chuck`
  `killall jackd`
end

audio = Dir[File.join(ARGV[0],"**","*.{wav,WAV,aif,aiff,AIF,AIFF}")]
samples = audio.collect{|f| Sample.new f}

# remove stale metadata files
meta = Dir[File.join(ARGV[0],"**","*.json")]
meta.each { |f| puts `trash "#{f}"` if Dir[f.sub("json","*")].size == 1 and !f.match(/scenes\.json/)}

# remove stale mfcc files
mfcc = Dir[File.join(ARGV[0],"**","*.mfcc")]
mfcc.each { |f| puts `trash "#{f}"` if Dir[f.sub("mfcc","*")].size == 1 }

# remove stale onsets files
onsets = Dir[File.join(ARGV[0],"**","*.onsets")]
onsets.each { |f| puts `trash "#{f}"` if Dir[f.sub("onsets","*")].size == 1 }

# normalize
samples.each { |s| s.normalize }

# check tags
samples.each do |s|
  unless s.type and ["drums","music"].include? s.type
    stay = true
    while stay do
      play s
      puts "\e[2J"
      choose do |menu|
        menu.prompt = "Sample type of #{s.name}?"
        menu.choice("play") { play s }
        menu.choice("stop") { stop }
        menu.choice(:drums) { s.type = "drums"; s.save; stop; stay = false }
        menu.choice(:music) { s.type = "music"; s.save; stop; stay = false }
        menu.choice(:skip) { stop; stay = false }
      end
    end
  end
  unless s.energy and ["up","down","constant","variable"].include? s.energy
    stay = true
    while stay do
      puts "\e[2J"
      choose do |menu|
        menu.prompt = "Energy level of #{s.name}?"
        menu.choice("play") { play s }
        menu.choice("stop") { stop }
        menu.choice(:up) { s.energy = "up"; s.save; stop; stay = false }
        menu.choice(:down) { s.energy = "down"; s.save; stop; stay = false }
        menu.choice(:constant) { s.energy = "constant"; s.save; stop; stay = false }
        menu.choice(:variable) { s.energy = "variable"; s.save; stop; stay = false }
        menu.choice(:skip) { stop; stay = false }
      end
    end
  end
  unless s.rhythm and ["straight","break"].include? s.rhythm
    stay = true
    while stay do
      puts "\e[2J"
      choose do |menu|
        menu.prompt = "Rhythm of #{s.name}?"
        menu.choice("play") { play s }
        menu.choice("stop") { stop }
        menu.choice(:straight) { s.rhythm = "straight"; s.save; stop; stay = false }
        menu.choice(:break) { s.rhythm = "break"; s.save; stop; stay = false }
        menu.choice(:skip) { stop; stay = false }
      end
    end
  end
  unless s.presence and ["foreground","background"].include? s.presence
    stay = true
    while stay do
      puts "\e[2J"
      choose do |menu|
        menu.prompt = "Presence of #{s.name}?"
        menu.choice("play") { play s }
        menu.choice("stop") { stop }
        menu.choice(:foreground) { s.presence = "foreground"; s.save; stop; stay = false }
        menu.choice(:background) { s.presence = "background"; s.save; stop; stay = false }
        menu.choice(:skip) { stop; stay = false }
      end
    end
  end
end

# adjust bars
samples.each do |s|
  unless [2.0,4.0,6.0,8.0,12.0,16.0,24.0,32.0,48.0,64.0,96.0,112.0,128.0].include? s.bars.round(2)
    stay = true
    dir = "/home/ch/music/loops/cut/#{s.bpm}/"
    while stay do
      puts "\e[2J"
      choose do |menu|
        menu.header = "#{s.file}: #{s.bars} bars"
        menu.choice("play") { play s }
        menu.choice("stop") { stop }
        menu.choice("move to #{dir}") { 
          stop
          `mkdir -p #{dir}` 
          puts `mv -iv "#{s.file}" #{dir}` 
          stay = false
        }
        menu.choice("delete") {
          stop
          puts `trash "#{s.file}"`
          stay = false
        }
        menu.choice("skip") { stop; stay = false }
      end
    end
  end
end

def display sample
  Process.detach spawn("display '#{sample.png}'")
end

=begin

# find/remove duplicates
#threshold=0.95
threshold=0.9
@matrix = []
say "Calculating similarities ..."
last = samples.size-1
(0..last).each do |i|
  @matrix[i] ||= []
  @matrix[i][i] = true
  (i+1..last).each do |j|
    sim = samples[i].similarity samples[j]
    if sim > threshold
      @matrix[j] ||= []
      @matrix[i][j] = true
      @matrix[j][i] = true
    end
  end
end

# disconnected subgraphs
# http://math.stackexchange.com/questions/277045/easiest-way-to-determine-all-disconnected-sets-from-a-graph

@components = []
@visited = []

def search i
  unless @visited.include? i
    @visited << i
    if @matrix[i].compact.size > 1
      @matrix[i].each_with_index do |v,j|
        if v and !@visited.include? j
          @components.last << j
          search j
        end
      end
    end
  end
end

@matrix.each_with_index do |row,i|
  if row.compact.size > 1 and !@visited.include? i
    @components << [i]
    search i
  end
end

@components.each do |component|
  component = component.collect{|i| samples[i]}
  stay = true
  while stay do
      puts "\e[2J"
    choose do |menu|
      menu.header = "\n"+component.collect{|s| "#{s.name}: #{s.bars.round}"}.join(", ")
      component.each do |s|
        menu.choice("play \"#{s.name}\"".to_sym) { play s; menu.prompt = "#{s.name} playing" }
      end
      # TODO: single display
      component.each do |s|
        menu.choice("display \"#{s.name}\"".to_sym) { display s }
      end
      component.each do |s|
        menu.choice("delete \"#{s.name}\"".to_sym) { stop; s.delete; component.delete s }
      end
      menu.choice("stop") { stop }
      menu.choice("next") { stop; stay = false }
    end
  end
end

#p matrix
p del#.join "\n"
puts
p del.uniq#.join "\n"
p del.size
p del.uniq.size
    end
  end
end

p del
#del.each{|s| puts `trash "#{s.file}"`}
=end
