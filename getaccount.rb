#!/usr/bin/env ruby
require 'net/http'
require 'net/https'
require 'net/smtp'
require 'uri'
require 'rubygems'
require 'markaby'
require 'json'
require 'pp'

user=ARGV[0]

def get_base_url()
  url = "https://my.vocalocity.com/appserver/rest"
end

def get_response_from_url(url)
  url = get_base_url + url
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(uri.request_uri)
  request.basic_auth("_bsmith", "8317mr")
  puts "get_response_from_url: fetching #{url} ..."
  response = http.request(request)
  data = response.body
  result = JSON.parse(data)
  puts JSON.pretty_generate(result)
  return result
end

def get_account(account)
  puts "ACCOUNT :: #{account}"
  result = get_response_from_url("/object/Account/#{account}")
end

def get_contact_info_from_account(account)
	puts "ACCOUNT RESPONSE:: #{account}"
  name = account["ContactName"]
  did = account["ContactPhone"]
  email = account["ContactEmail"]
  info = { :name => name, :phone => did, :email => email }
end

def get_account_id_from_dk_id(dk_id)
  puts "DKID :: #{dk_id}"
  result = get_response_from_url("/search/AccountServices?deviceKitId=#{dk_id}")
  account = result.fetch("AccountServicesList").first.fetch("AccountId")
end

def get_device_kit_from_device_property_value(sipid)
  puts "SIPID :: #{sipid}"
  result = get_response_from_url("/search/DeviceProperties?property_value=#{sipid}")
  dk = result.fetch("DevicePropertiesList").first.fetch("DeviceGuidObject").fetch("DeviceKitId")
end

def get_device_from_dk_id(dk_id)
  puts "DKID :: #{dk_id}"
  result = get_response_from_url("/search/Devices?childDeviceKitObject.deviceKitId=#{dk_id}&childDeviceKitObject.deviceKitTypeId=1&deviceTypeId=9")
  device = result.fetch("DevicesList").first.fetch("DeviceGuid")
end

def get_ext_number_from_device(device)
  puts "DEVICE :: #{device}"
  result = get_response_from_url("/search/DeviceProperties?deviceGuid=#{device}&propertyGuid=157")
  ext = result.fetch("DevicePropertiesList").first.fetch("PropertyValue")
end

def get_data_for_user(user)
  device_kit = get_device_kit_from_device_property_value(user)
  account_id = get_account_id_from_dk_id(device_kit)
  account = get_account(account_id)
  info = get_contact_info_from_account(account)
  extension = get_ext_number_from_device(get_device_from_dk_id(get_device_kit_from_device_property_value(user)))
  puts " -- Account Data: #{account_id}, #{extension} - #{user}, #{info[:name]}, #{info[:phone]}, #{info[:email]} --"
end

puts "getting info for user #{user} ..."
get_data_for_user(user)
