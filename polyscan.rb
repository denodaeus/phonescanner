#!/usr/bin/env ruby
require 'net/http'
require 'net/smtp'
require 'uri'
require 'rubygems'
require 'markaby'
require 'json'

# read in some csv files, look for public IP addresses
# if public, probe it for a web server
# if a web server responds, check to see if it's a SIP phone
# if a SIP phone, attempt to log in
# if login succeeds, attempt to get SIP password
# echo results to console and create a CSV file of exposed phones
# 

# script assumes two folders named "input" and "output" which
# contain or will contain the necessary csv files


###############################################################################
# TO DO
#
# Fix bug: :undefined method `[]' for nil:NilClass (probably in page title check)
# -- actually in the check for server or auth headers, need to protect against nil values here
#
# Add a feature that prevents repeat scanning of an IP address

# CONFIGURATION INFORMATION ###################################################
start_time = Time.now
now = start_time.strftime('%Y%m%d-%H%M%S')
input_filenames = ['mergedproxy-sorted.csv']
input_folder = "proxy"
output_folder = "output"
output_csv = "#{output_folder}/polyscan-results.csv"

dotcount=1

@sip_phone_rgx = /Aastra|Polycom/
@private_ip_rgx = /192\.168|10\.|172.[16..31]/

# METHODS #####################################################################

#pass in ip, user, password, path, regex for password match
# return hash of :login_status, :sip_password

def attempt_login(ip,user,pw,path,rgx)
  # Set up HTTP GET
  uri = URI.parse("http://" << ip << path)
  puts "Fetching " << uri.to_s << "\n\n"
  http_grab = Net::HTTP.new(uri.host)
  http_grab.open_timeout = 10 # seconds
  http_grab.read_timeout = 10 # second
  request = Net::HTTP::Get.new(uri.request_uri)
  request.basic_auth user, pw
  response = http_grab.request(request)

  # Check for denial
  if response.code =~ /401/
    puts "..... Login Failed\n\n"
    result = "Fail"
  else
    result = "Success"
    puts "***** Login Success\n\n"
    
    # Check for SIP Password
    if response.body =~ rgx
      sip_pw = rgx.match(response.body)[1]

      if sip_pw =~ /\?\?\?\?/
          status = "masked"
          puts "..... Password Masked\n\n"
          
      elsif sip_pw =~ /.*/
          status = "exposed"
          puts "$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
          puts "$$$$$                  $$$$$"
          puts "$$$$$ PASSWORD EXPOSED $$$$$"
          puts "$$$$$                  $$$$$"
          puts "$$$$$$$$$$$$$$$$$$$$$$$$$$$$\n\n"
          puts "Last 3 characters of sip password:" << sip_pw[-3..-1] << "\n\n"
          
      else
          status = "none"
          puts "No password found\n\n"
      end
      
    else
      puts "Password not found"
      sip_pw = nil
    end
  end
  
  #return results
  login_result = { :login_status => result, :pw_status => status, :sip_pw => sip_pw} 
end

def post_for_file(ip, user, pw, url, savepath)
	http_request = Net::HTTP.new(url)
  puts "Grabbing file for " + savepath
  http_request.open_timeout = 10
	http_request.read_timeout = 10
  request = Net::HTTP::Get.new(url.request_uri)
  request.basic_auth user, pw
	response = http_request.request(request)
end

def get_base_url(server)
  url = "http://#{server}:8080/appserver/rest/"
end

def get_response_from_url(url)
  url = get_base_url + url
  response = Net::HTTP.get_response(URI.parse(url))
  data = response.body
  result = JSON.parse(data)
end 

def get_account(account)
  result = get_response_from_url("/object/Account/#{account}")
end

def get_contact_info_from_account(account)
  name = account.get("ContactName")
  did = account.get("ContactPhone")
  email = account.get("ContactEmail")
  info = { "name" => name, "phone" => phone, "email" => email }
end

def get_account_id_from_dk_id(dk_id)
  result = get_response_from_url("/search/AccountServices?deviceKitId=#{dk_id}")
  account = result.get("AccountId")
end

def get_device_kit_from_device_property_value(sipid)
  result = get_response_from_url("/search/DeviceProperties?property_value=#{sipid}")
  dk = result.get("DeviceKitId")
end

def get_device_from_dk_id(dk_id)
  result = get_response_from_url("/search/Devices?childDeviceKitObject.deviceKitId=#{dk_id}&childDeviceKitObject.deviceKitTypeId=1&deviceTypeId=1")
  device = result.get("DeviceGuid")
end

def get_ext_number_from_device(device)
  result = get_response_from_url("/search/DeviceProperties?deviceGuid=#{device}&propertyGuid=158")
  ext = result.get("PropertyValue")
end

def get_data_for_user(user)
  account = get_device_kit_from_device_property_value(user)
end

# SEND EMAIL SUMMARY OF REPORT
# usage:
# send_email "root@localhost" msg, opts[:from], to, attachment
def send_email(to, opts={})
  opts[:server]      ||='localhost'
  opts[:from]        ||='root@localhost'
  opts[:from_alias]  ||='Phone Scanner'
  opts[:subject]     ||='Phone Scanner Report for ' + Time.new
  opts[:body]        ||=''
  opts[:attachment]  ||=''
  
  msg = <<END_OF_MESSAGE
  From: #{opts[:from_alias]} <#{opts[:from]}>
  To: <#{to}>
  Subject: #{opts[:subject]}

  #{opts[:body]}
END_OF_MESSAGE

  Net::SMTP.start(opts[:server]) do |smtp|
    smtp.send_message(msg, opts[:from], to)
  end
end

# BEGIN #########################################################

File.open(output_csv, 'w') do |out_file|
  
  # Write headers
  out_file << "Account,User,IP Address,Manufacturer,Model,Firmware,Server type,HTTP Response code,HTTP Message,Page Title,Login Attempt,Password \n"
  
  input_filenames.each do |filename|
    if File.exists? "#{input_folder}/#{filename}"
      puts "Working on \"#{filename}\"...\n\n"

			entries = Hash.new
      File.open("#{input_folder}/#{filename}").each do |line|
        
        # How many phones processed?
        print "#{dotcount}: "
      	dotcount += 1
      	
      	#testing kill switch
      	#break unless dotcount < 10
        
        #split line on commas
        e = line.split(",")

        # Account information from file
        account = e[0]
        user = e[1]
        maker = e[2]
        model = e[3]
        firmware = e[4]
        ip = e[5]
        external_ip = e[6]

        if external_ip == nil
          external_ip = "No External IP"
        end
          
        print "#{account}.#{user} - #{ip}\n\n"
        
        # if it's not private, check for a server
        unless ip =~ @private_ip_rgx
          
          begin
						  entry = entries["#{ip}"]
							if entry.nil?
								entries["#{ip}"] = "#{model}"
							else
								entries["#{ip}"] += ",#{model}"				
							end
						
						puts "entry ... #{ip} for #{entries[ip]}"

            uri = URI.parse("http://#{ip}")
            http = Net::HTTP.new(uri.host)
            http.open_timeout = 1 # seconds
            http.read_timeout = 1 # second
            request = Net::HTTP::Get.new(uri.request_uri)
            response = http.request(request)
            
            #Code below executes if a server is found
            puts "..... SERVER FOUND\n\n"
            r = response.to_hash()
            r.each do |k,v|
              puts "#{k} => #{v}"
            end
            
            #Extract contents of title tag
            title_rgx = /<title>(.*)<\/title>/
            if response.body =~ title_rgx
              title = response.body.match(title_rgx)[1].nil? ? "" : response.body.match(title_rgx)[1]
            end
            
            # Grab Server Response
            code = response.code
            msg = response.msg
            server = response['server'].nil? ? "" : response['server']
            auth = response['www-authenticate'].nil? ? "" : response['www-authenticate']
            
            puts "Response code #{code}"
            puts "Message: #{msg}"
            puts "Page Title: #{title}\n\n"

            ##################################################
            #
            # Check for known devices
            #
            # If one is found, attempt to log in and obtain password
            
            #Polycom found
            if server =~ /Polycom/ 
              puts "\n\n::::: POLYCOM DETECTED\n\n"
              
              #Can we log in?
              def_user = "Polycom"
              def_pw = "456"
              
              # Specify page and regex to look for sip password
              case firmware
              when /\A3.2/
                sip_rgx = /<input.* name="reg.1.auth.password" value="(.*)".*>/
                path = "/reg_1.htm"
              when /\A3.1/
                sip_rgx = /<input.*value="(.*)" size.*name="reg.1.auth.password".*>/
                path = "/reg_1.htm"
              when /\A2/
                sip_rgx = /<input.*value="(.*)" type.*name="reg.1.auth.password".*>/
                path = "/reg.htm"
              end
              
              # Go for it
              login = attempt_login(ip,def_user,def_pw,path,sip_rgx)
              
              
            #Aastra found
            elsif auth =~ /Aastra/
              puts "\n\n::::: AASTRA DETECTEDn\n"
              
              #Can we log in?
              def_user = "admin"
              def_pw = "22222"
              path = "/globalSIPsettings.html"
              sip_rgx = /<input name="password" type="password" value="(.*)" \/>/
              login = attempt_login(ip,def_user,def_pw,path,sip_rgx)
              
            #Edgemarc found
            elsif auth =~ /System/
              puts "\n\n::::: EDGEMARC DETECTED\n\n"
              
              #Can we log in?
              maker = "Edgemarc"
              def_user = "root"
              def_pw = "default"
              path = ""
              sip_rgx = //           
              login = attempt_login(ip,def_user,def_pw,path,sip_rgx)

            
            #Cisco found
            elsif title =~ /SPA.*Configuration Utility/
              puts "\n\n::::: CISCO SPA DETECTED \n\n"
              def_user = ""
              def_pw = ""
              path = ""
              sip_rgx = //
              login = attempt_login(ip,def_user,def_pw,path,sip_rgx)
              
            #Linksys found
            elsif title =~ /Linksys/
              puts "\n\n::::: LINKSYS DETECTED\n\n"
              def_user = ""
              def_pw = ""
              path = ""
              sip_rgx = //
              login = attempt_login(ip,def_user,def_pw,path,sip_rgx)

						elsif auth =~ /IP phone/
							puts "\n\n::::: YEALINK DETECTED\n\n"
							def_user = "admin"
							def_pw = "admin"
							path="/ConfigManApp.com?Id=26"
							# TODO:  need to post for a file download and scrape the file download for a password
							#				 but for now this will identify and authenticate a yealink
							sip_rgx = //
							login = attempt_login(ip,def_user,def_pw,path,sip_rgx)
            else
              do_not_log = true
            end

						if login != nil
            	if login[:login_status] =~ /Fail/
              	do_not_log = true
            	else
              	do_not_log = nil
            	end
						end

            # So, what happened?
            
            #Check to see if we write to file
            if do_not_log == nil
              puts "writing to file\n\n"
              out_file << "#{account},#{user},#{ip},#{maker},#{model},#{firmware},#{server},#{code},#{msg},#{title},#{login[:login_status]},#{login[:pw_status]} \n"
              do_not_log = nil
            end  

          # Handle network errors. Greedy  
          #rescue Exception
           rescue => e
							puts ": ERROR: " + e
						 #puts ": ERROR #{$!}\n\n" # if there's an error, print it
						puts e.backtrace
					rescue Exception
						puts ": ERROR #{$!}\n\n"
          end #begin
          
        else
          
          puts "Private IP\n\n"
        end #unless
        puts "--------------------------------------------------"
        puts "#{Time.now - start_time} seconds elapsed" 
        puts "--------------------------------------------------\n\n"
        
      end
      puts "DONE"
    else
      # If the input file isn't there, handle it
      puts "Warning: File \"#{filename}\" does not exist; skipping."
    end
    
  end # input file block
end #file open block

puts "Elapsed time: #{Time.now - start_time} seconds"
puts "File written to: #{output_csv}"
