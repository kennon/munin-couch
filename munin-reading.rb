require 'couch_db'
require 'rubygems'
require 'json'

host = ARGV[0]

if host.nil?
  puts "Syntax: ./munin-reading.rb <hostname> (port)"
  exit 1
end

port = ARGV[1] || 4949

couch = CouchDb.new("localhost", "5984")

# 1. try to connect to HOST
# => # munin node at HOSTNAME

munin = TCPSocket.open(host, port)

hello = munin.gets

hostname = hello.match(/# munin node at ([\w.]+)/)[1]
puts "HOSTNAME: #{hostname}"

# 2. run command 'list', receive list of services: (single line)
# => open_inodes mysql_slowqueries irqstats if_eth0 apache_accesses mysql_threads df swap uptime load multimemory postfix_mailstats cpu df_inode mysql_queries open_files iostat forks memory vmstat apache_processes if_err_eth0 entropy processes postfix_mailqueue apache_volume interrupts netstat mysql_bytes if_eth1 if_err_eth1 postfix_mailvolume passenger_status

munin.puts "list"

services = munin.gets

services = services.split(' ')
puts "SERVICES: #{services.inspect}"

# XXX
#services = ['passenger_status']

# get services.size unique ids
uuids = couch.get("/_uuids?count=#{services.size}")
uuids = uuids["uuids"]

services.each do |service|
  # 3. for each service, run command 'config' example: "config if_eth1"
  # => graph_title Inode table usage
  # => graph_args --base 1000 -l 0
  # => graph_vlabel number of open inodes
  # => graph_category system
  # => graph_info This graph monitors the Linux open inode table.
  # => used.label open inodes
  # => used.info The number of currently open inodes.
  # => max.label inode table size
  # => max.info The size of the system inode table. This is dynamically adjusted by the kernel.
  # => .
  # (ends in .)

  munin.puts "config #{service}"
  graph = {}
  config = {}

  while (line = munin.gets.chop) && (line != '.')
    case line
    when /^graph_/
      # pull graph_title, graph_category, graph_info, then each unique identifier after that
      #  for each unique identifier, pull .label, .info, .type
      
      matches = line.match /^graph_(\w+) (.*)$/
      attribute = matches[1]
      value = matches[2]
      
      graph[attribute] = value
    when ' '
      # noop
    else
      matches = line.match /^(\w+)\.(\w+) (.*)$/

      fieldname = matches[1]
      attribute = matches[2]
      value = matches[3]

      config[fieldname] ||= {}
      config[fieldname][attribute] = value
    end
  end

  # 6. for each service run command 'fetch' example: 'fetch if_eth1'
  # => down.value 0
  # => up.value 492
  # => .

  munin.puts "fetch #{service}"
  data = {}
  while (line = munin.gets.chop) && (line != '.')
    matches = line.match /^(\w+)\.value (.*)$/
    fieldname = matches[1]
    value = matches[2]
    data[fieldname] = value
  end

  # 7. create a document for the reading
  doc = {:host => hostname, :service => service, :date => Time.now.utc.strftime("%Y-%m-%d %H:%M:%S"), :graph => graph, :config => config, :data => data}

  # 8. save document to couchdb
  uuid = uuids.pop
  couch.put "/munin/#{uuid}", doc.to_json
end

# close connection to munin
munin.puts "quit"
