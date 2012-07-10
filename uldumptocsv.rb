#!/usr/bin/env ruby

dump_file=ARGV[0]

File.open("proxy/#{dump_file}-parsed.csv", "w") { |out_file|
    out_file.puts "username,contact,received,user_agent"
    line = []
    new_entry = false
    entry = []

    IO.foreach(dump_file) do |line|
        text = ""
        if line =~ /AOR/
            out_file.puts entry.join("\t")
            new_entry = true
            entry = []
            sipid = line.split("AOR:: ")[1].chomp
            entry[0] = sipid + "." + sipid
        elsif line =~ /Contact/
            new_entry = false
            entry[1] = line.split("Contact:: ")[1].chomp
        elsif line =~ /Received/
            new_entry = false
            entry[2] = line.split("Received:: ")[1].chomp
        elsif line =~ /User-agent/
            new_entry = false
            entry[3] = line.split("User-agent:: ")[1].chomp
        #elsif line =~ /Callid/
        #    new_entry = false
        #    entry[4] = line.split("Callid:: ")[1].chomp
        end
    end
}
