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

require 'socket'
health_server = Thread.new do
  server = TCPServer.new('0.0.0.0', 1234)
  puts "Health check server listening on port 1234"
  loop do
    sock = server.accept
    sock.gets
    sock.write("HTTP/1.0 200 OK\n\nok")
    sock.close
  end
end

puts "Bot is running. Press Ctrl+C to stop."
begin
  # WebSocketの接続が維持される限り実行し続ける
  sleep
rescue Interrupt
  puts "\nShutting down gracefully..."
  client.stop
  health_server.kill
end 
