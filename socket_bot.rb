#!/usr/bin/env ruby
require 'dotenv'
Dotenv.load

require_relative 'lib/socket_mode/client'

%w[SLACK_BOT_TOKEN SLACK_APP_TOKEN].each do |env_var|
  unless ENV[env_var]
    puts "Error: #{env_var} environment variable is missing"
    exit 1
  end
end

puts "Starting Slack-AFK in Socket Mode..."

client = SocketMode::Client.new
client.start

puts "Bot is running. Press Ctrl+C to stop."
begin
  # WebSocketの接続が維持される限り実行し続ける
  sleep
rescue Interrupt
  puts "\nShutting down gracefully..."
  client.stop
end 
