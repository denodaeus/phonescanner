#!/usr/bin/env ruby
require 'rubygems'
require 'markaby'

######## CONFIG STUFF
now = Time.now.strftime('%Y%m%d-%H%M%S')
filename = 'polyscan-results.csv'
input_filenames = [filename] 
input_folder = "output"
output_folder = "output"
output_html = "#{output_folder}/#{filename}.htm"
ip_rgx = /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/

#Load CSV File into array of hashes
html_array = Array.new
input_filenames.each do |filename|
  if File.exists? "#{input_folder}/#{filename}"
    puts "Parsing \"#{filename}\"..."
    File.open("#{input_folder}/#{filename}").each do |line|
      la = line.split(",")
      html_array << la
      la.each do |f|
        print f
      end
      puts "----"
    end
    else
      # If the input file isn't there, handle it
      puts "Warning: File \"#{filename}\" does not exist; skipping."
  end
end


# Write HTML file
mab = Markaby::Builder.new
mab.html do
  head { title "Exposed Phone Report - A4 & A5 - #{Time.now}" }
    body do
      h1 "Exposed Phone Report - A4 / A5 - #{Time.now}"
      table(:border => 1, :cellpadding => 3) do
        html_array.each do |h|
          tr do
            h.each do |f|
              if f =~ ip_rgx
                td { a f, :href => "http://#{f}", :target => 'blank' }
              elsif f =~ /exposed|Success/
                td(:bgcolor=>'#FF4D4D') {f}
              elsif f =~ /Edgemarc/
                td(:bgcolor=>'#FFFF66') {f}
              else
                td f
              end
            end
          end
        end
      end
    end
end



File.open(output_html, 'w') do |html_out_file|
  html_out_file << mab.to_s
end