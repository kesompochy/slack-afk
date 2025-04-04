require 'slack-ruby-client'
require 'faye/websocket'
require 'json'
require 'uri'
require 'eventmachine'
require_relative './dispatcher'

Slack.configure do |config|
  config.token = ENV['SLACK_BOT_TOKEN']
end

module SocketMode
  class Client
    attr_reader :web_client, :dispatcher
    
    def initialize
      @web_client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
      @dispatcher = Dispatcher.new(@web_client)
      @ws = nil
      @running = false
      @reconnect_mutex = Mutex.new
      @reconnect_requested = false
      @reconnect_attempts = 0
    end
    
    def start
      @running = true
      
      Thread.new do
        EM.run do
          connect_socket
        end
      end
      
      puts "Socket Mode client started"
    end
    
    def stop
      @running = false
      close_connection
      EM.stop if EM.reactor_running?
      puts "Socket Mode client stopped" if ENV['DEBUG']
    end
    
    private
    
    def close_connection
      return unless @ws
      @ws.close
      @ws = nil
    end
    
    def connect_socket
      return unless @running
      
      begin
        app_client = Slack::Web::Client.new(token: ENV['SLACK_APP_TOKEN'])
        response = app_client.apps_connections_open
        
        unless response['ok']
          puts "Failed to get Socket Mode URL: #{response['error'] || 'unknown error'}"
          request_reconnect
          return
        end
        
        wss_url = response['url']
        puts "Socket Mode URL obtained: #{wss_url}" if ENV['DEBUG']
        
        @ws = Faye::WebSocket::Client.new(wss_url, nil, { ping: 30 })
        
        @ws.on :open do |event|
          puts "WebSocket connection established" if ENV['DEBUG']
          @reconnect_attempts = 0
        end
        
        @ws.on :message do |event|
          data = event.data
          
          if data.is_a?(String) && data.start_with?('Ping from')
            puts "Received ping: #{data}" if ENV['DEBUG']
            next
          end
          
          begin
            data = JSON.parse(data)
            
            if data['envelope_id']
              ack = { envelope_id: data['envelope_id'] }.to_json
              @ws.send(ack)
              puts "Acknowledged event with envelope_id: #{data['envelope_id']}" if ENV['DEBUG']
            end
            
            case data['type']
            when 'hello'
              puts "Connected to Socket Mode" if ENV['DEBUG']
            when 'disconnect'
              puts "Received disconnect request: #{data['reason']}" if ENV['DEBUG']
              request_reconnect
            when 'events_api'
              handle_events_api(data)
            when 'slash_commands'
              handle_slash_commands(data)
            when 'interactive'
              puts "Received interactive event: #{data['payload']['type']}" if ENV['DEBUG']
            else
              puts "Received unknown event type: #{data['type']}" if ENV['DEBUG']
            end
          rescue JSON::ParserError => e
            puts "JSON parse error: #{data.inspect}" if ENV['DEBUG']
          rescue => e
            puts "Message processing error: #{e.message}"
            puts e.backtrace.join("\n") if ENV['DEBUG']
          end
        end
        
        @ws.on :error do |event|
          puts "WebSocket error: #{event.message}"
          request_reconnect
        end
        
        @ws.on :close do |event|
          puts "WebSocket disconnected: #{event.code} #{event.reason}" if ENV['DEBUG']
          request_reconnect if @running
        end
      rescue => e
        puts "Socket Mode initialization error: #{e.message}"
        puts e.backtrace.join("\n") if ENV['DEBUG']
        request_reconnect
      end
    end
    
    def request_reconnect
      @reconnect_mutex.synchronize do
        return if @reconnect_requested
        @reconnect_requested = true
        
        @reconnect_attempts += 1
        delay = [2 ** @reconnect_attempts, 30].min
        
        puts "Reconnecting in #{delay} seconds (attempt #{@reconnect_attempts})" if ENV['DEBUG']
        
        EM.add_timer(delay) do
          @reconnect_requested = false
          close_connection
          connect_socket
        end
      end
    end
    
    def handle_events_api(data)
      event_type = data.dig('payload', 'event', 'type')
      puts "Event received: #{event_type || 'unknown'}" if ENV['DEBUG']
      
      if ENV['DEBUG']
        event = data.dig('payload', 'event')
        if event
          puts "Event details:"
          puts "  Type: #{event['type']}"
          puts "  Channel: #{event['channel']}" if event['channel']
          puts "  User: #{event['user']}" if event['user']
          puts "  Text: #{event['text']}" if event['text']
        end
      end
      
      @dispatcher.dispatch_event(data)
    end
    
    def handle_slash_commands(data)
      command = data.dig('payload', 'command')
      puts "Slash command received: #{command || 'unknown'}" if ENV['DEBUG']
      @dispatcher.dispatch_command(data)
    end
  end
end 
