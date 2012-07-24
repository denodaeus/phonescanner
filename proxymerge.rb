#!/usr/bin/env ruby

# Pull in CSV files of phone registrations, extracted from mysql on a4 and a5 proxies
# Parse the files into a single outfile that is stripped of garbage characters

# Query to use
# A5: 
# select username, contact, received, user_agent from location order by user_agent into outfile '/tmp/a5.csv';
#
# A4:
# select username, contact, received, user_agent from location order by user_agent into outfile '/tmp/a4.csv';


############################## CONFIG 

time_now = Time.now.strftime('%Y%m%d-%H%M%S')
input_folder = "proxy"
input_filenames = ['vocalocity.csv']
output_folder = "proxy"
output_filename = "#{input_folder}/mergedproxy.csv"

aastra_m_rgx = /(Aastra \d*\w*)/
aastra_f_rgx = /\/(\d+.\d+.\d+.\d+)\s/
oldcisco_m_rgx = /-(.*)\//
oldcisco_f_rgx = /\/(.*)/
newcisco_m_rgx = /\/(.*)-/
newcisco_f_rgx = /(\d+\.\d+.\d+[a-z]*)/
linksys_m_rgx = /\/(.*)-/
linksys_f_rgx = /-(.*)/
polycom_m_rgx = /-(.*)-/
polycom_f_rgx = /\/(.*)/

ip_rgx = /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/
phone_model_rgx = /Aastra|Polycom|Linksys|Cisco|eyeBeam|Bria|Zoiper|Acrobits|fring|X-Lite|3CXPhone|A580|Blink|CSCO|DPH|Ekiga|ewua|Grandstream|snom|Helios|IVM|op3|PBX|S675|SIPAUA|Sipura|SpeedTouch|Telephone|Audiocodes|Cyberdata|Media5|Panasonic|Yealink/

# Output file fields:
# Account, User, Phone Make, Phone Model, Phone Firmware, Internal IP, External IP


############################## CODE

 
File.open(output_filename, 'w') do |out_file|
  
  input_filenames.each do |filename|
    if File.exists? "#{input_folder}/#{filename}"
      puts "Parsing \"#{filename}\"..."
      File.open("#{input_folder}/#{filename}").each do |line|
        puts " ... #{line}" 
        #Split each line into distinct elements
        elements = line.split("\t")
        this_user = elements[0].split('.')[0]
        this_account = elements[0].split('.')[1]
        internal_ip = elements[1][ip_rgx]
        external_ip = elements[2][ip_rgx]
        if !external_ip
          external_ip = "none"
        end
        
        
        #Figure out phone make and model
        phone_make = elements[3].match(phone_model_rgx).to_s
        
        #Which Cisco?
        if phone_make == "Cisco"
          if elements[3].match(/CP/)
            phone_make = "Cisco 79xx"
          else
            phone_make = "Cisco SPA"
          end
        end
        
        # puts phone_make << " : " << elements[3]

        #Test for Polycom, Aastra, Cisco or Linksys
        # Tom's RubyFu: f.match(/-(.*)-/) { |m| # do something with m }  

        case phone_make
          when "Polycom"
            this_model = elements[3].match(polycom_m_rgx)[1]
            this_firmware = elements[3].match(polycom_f_rgx)[1]
          when "Aastra" 
            this_model = elements[3].match(aastra_m_rgx)[1]
            this_firmware = elements[3].match(aastra_f_rgx)[1] unless !elements[3].match(aastra_f_rgx) #Take into account wacky Aastra MBU
          when "Linksys"
            this_model = elements[3].match(linksys_m_rgx)[1]
            this_firmware = elements[3].match(linksys_f_rgx)[1]
          when "Cisco 79xx"
            this_model = elements[3].match(oldcisco_m_rgx)[1]
            this_firmware = elements[3].match(oldcisco_f_rgx)[1]
          when "Cisco SPA"
            this_model = elements[3].match(newcisco_m_rgx)[1]
            this_firmware = elements[3].match(newcisco_f_rgx)[1]
        end


        out_file <<  "#{this_account},#{this_user},#{phone_make},#{this_model},#{this_firmware},#{internal_ip},#{external_ip}\n"
      end
    end
  end
end

# Sort file. Can I do this inline above?
File.open("#{input_folder}/mergedproxy-sorted.csv", "w") do |file|
  File.readlines("#{output_folder}/mergedproxy.csv").sort.each do |line|
    file.write(line.chomp<<"\n")
  end
end
