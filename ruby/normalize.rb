#!/bin/env ruby
require 'fileutils'


bakdir = "/tmp/normalize/"
date = `date +\"%Y%m%d_%H%M%S\"`.chomp
backup = File.join bakdir, File.basename(ARGV[0])+"."+date
FileUtils.mkdir_p bakdir
FileUtils.cp ARGV[0], backup
stat = Hash[`sox "#{ARGV[0]}" -n stat 2>&1|sed '/Try/,$d'`.split("\n")[0..14].collect{|l| l.split(":").collect{|i| i.strip}}]
max_amplitude = [stat["Maximum amplitude"].to_f,stat["Minimum amplitude"].to_f.abs].max
unless  max_amplitude > 0.95
  puts "normalizing #{ARGV[0]} (#{max_amplitude})"
  `sox -G --norm "#{backup}" "#{ARGV[0]}"`
end

