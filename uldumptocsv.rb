#!/usr/bin/env ruby

# script to convert from opensips mi_fifo output to polyscan expected input
# ./uldumptocsv.rb FILE_NAME

dump_file=ARGV[0]


File.open("#{dump_file}-parsed.csv", "w") { |out_file|
    line = []
    new_entry = false
    entry = []
    start = true

    IO.foreach(dump_file) do |line|
        text = ""
        if line =~ /Domain/
          puts "Beginning parsing of #{dump_file}"
        elsif line =~ /AOR/
            if start then start = false else out_file.puts entry.join("\t") end
            new_entry = true
            entry = []
            sipid = line.split("AOR:: ")[1].chomp
            entry[0] = sipid + "." + sipid
        elsif line =~ /Contact/
            new_entry = false
            entry[1] = line.split("Contact:: ")[1].split(" Q=")[0].chomp
        elsif line =~ /Received/
            new_entry = false
            entry[2] = line.split("Received:: ")[1].chomp
        elsif line =~ /User-agent/
            new_entry = false
            entry[3] = line.split("User-agent:: ")[1].chomp
        end
    end
}
