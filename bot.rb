if ARGV.length != 2
  puts 'Usage: ruby bot.rb <token> <client_id>'
  exit
end
require 'rubygems'

require 'bundler/setup'
Bundler.setup(:default)

require 'fileutils'
require 'yaml'
require 'discordrb'

FileUtils.touch('ids.yaml')
IDS = YAML.load_file('ids.yaml')
IDS ||= Hash.new
IDS.default = []

CHANNEL_ID = 305721854939758592

BOT = Discordrb::Bot.new token: ARGV.first, client_id: ARGV[1]

BOT.ready { |event| BOT.servers.each { |_, server| setup_server(server) }; save }

BOT.server_create do |event| 
  setup_server(event.server)
  save
end

def history(channel, count, last_id, sofar, target_id)
  messages = channel.history(count, nil, last_id)#, after_id: 305814901740535812)
  last_id = messages.last.id
  sofar += messages
  puts messages
  return (last_id == target_id ? sofar : history(channel, count, last_id, sofar, target_id))
end

def setup_server(server)
  return if server.id == 303952447712395264
  puts "Setting up [#{server.name}]"
  channel = server.text_channels.find { |tc| tc.name == 'sorteo_1000' }

  # RECURSIVE LOOP THROUGH HISTORY
  start_id = 305750110753783808
  target_id = channel.history(1).first.id # 305558605246234624

  IDS[server.id] = history(channel, 1, start_id, [], target_id).map { |m| m.author.id }

  IDS[server.id].uniq!

  puts "Counted #{IDS[server.id].length}"
end

BOT.message(in: CHANNEL_ID) do |event|
  unless IDS[event.server.id].include?(event.author.id)
    IDS[event.server.id] << event.author.id 
    puts "Added #{event.user.distinct}!"

    save
  end
end

BOT.pm(from: [152621041976344577, 228656614851346432], content: 'winner') do |event|
  # Get random winner
  server = event.bot.server(232329466825670657)
  ids = IDS[server.id]

  random = server.member(ids.sample)
  event.user.pm "**CHOICE:** #{random.display_name} (#{random.mention})\n*User since:* #{random.joined_at}"
  puts 'Selection: ' + random.mention
end

def save
  File.open('ids.yaml', 'w') {|f| f.write IDS.to_yaml }
end

perms = Discordrb::Permissions.new
perms.can_read_messages = true

#BOT.invisible
puts "Oauth url: #{BOT.invite_url}+&permissions=#{perms.bits}"

BOT.run