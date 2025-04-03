require 'slack-ruby-client'
require 'websocket-client-simple'
require 'json'
require 'uri'
require_relative './dispatcher'

Slack.configure do |config|
  config.token = ENV['SLACK_BOT_TOKEN']
end

module SocketMode
  class Client
    attr_reader :web_client, :socket_client, :dispatcher
    
    def initialize
      @web_client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
      @socket_client = nil
      @ws = nil
      @dispatcher = Dispatcher.new(@web_client)
      @running = false
      @reconnect_interval = 30
      @reset_thread = nil
    end
    
    def start
      connect_socket
      
      @main_thread = Thread.current
      @running = true
      
      start_periodic_reset
    end
    
    def stop
      @running = false
      stop_periodic_reset
      close_connection
      puts "Socket Mode client stopped" if ENV['DEBUG']
    end
    
    def reconnect
      puts "Reconnecting Socket Mode client..." if ENV['DEBUG']
      close_connection
      sleep 2
      connect_socket
    end
    
    private
    
    def close_connection
      if @ws
        begin
          @ws.close if !@ws.closed?
        rescue => e
          puts "Error closing WebSocket connection: #{e.message}"
        ensure
          @ws = nil
        end
      end
    end
    
    def start_periodic_reset
      stop_periodic_reset if @reset_thread
      
      @reset_thread = Thread.new do
        while @running
          begin
            sleep @reconnect_interval
            puts "Performing scheduled connection reset" if ENV['DEBUG']
            reconnect
          rescue => e
            puts "Error in reset thread: #{e.message}"
            sleep 5
          end
        end
      end
    end
    
    def stop_periodic_reset
      if @reset_thread && @reset_thread.alive?
        @reset_thread.kill
        @reset_thread = nil
      end
    end
    
    def connect_socket
      begin
        app_client = Slack::Web::Client.new(token: ENV['SLACK_APP_TOKEN'])
        response = app_client.apps_connections_open
        
        unless response['ok']
          puts "Failed to get Socket Mode URL: #{response['error'] || 'unknown error'}"
          return
        end
        
        wss_url = response['url']
        puts "Socket Mode URL obtained: #{wss_url}" if ENV['DEBUG']
        
        # クロージャでSocketClientインスタンスを参照するための変数
        client = self
        
        @ws = WebSocket::Client::Simple.connect(wss_url)
        ws_connection = @ws
        
        @ws.on :message do |msg|
          if msg.data.start_with?('Ping from')
            next
          end
          
          begin
            data = JSON.parse(msg.data)
            
            if data['envelope_id']
              ack = { envelope_id: data['envelope_id'] }.to_json
              begin
                ws_connection.send(ack)
              rescue => e
                puts "Failed to send acknowledge: #{e.message}" if ENV['DEBUG']
                if e.message.include?('closed')
                  client.reconnect
                end
              end
            end
            
            case data['type']
            when 'hello'
              puts "Connected to Socket Mode" if ENV['DEBUG']
            when 'disconnect'
              puts "Received disconnect request: #{data['reason']}" if ENV['DEBUG']
              client.reconnect
            when 'events_api'
              client.send(:handle_events_api, data)
            when 'slash_commands'
              client.send(:handle_slash_commands, data)
            when 'interactive'
            else
            end
          rescue JSON::ParserError => e
            puts "JSON parse error: #{msg.data.inspect}" if ENV['DEBUG']
          rescue => e
            puts "Message processing error: #{e.message}"
            puts e.backtrace.join("\n") if ENV['DEBUG']
          end
        end
        
        @ws.on :error do |e|
          puts "WebSocket error: #{e.message}"
          if client.instance_variable_get(:@running)
            puts "Reconnecting due to WebSocket error..." if ENV['DEBUG']
            client.reconnect
          end
        end
        
        @ws.on :close do |e|
          puts "WebSocket disconnected: #{e.code} #{e.reason}" if ENV['DEBUG']
          
          if client.instance_variable_get(:@running)
            puts "Reconnecting in 5 seconds..." if ENV['DEBUG']
            sleep 5
            begin
              client.reconnect
            rescue => err
              puts "Error during reconnection: #{err.message}" if ENV['DEBUG']
              puts "Will try again in 30 seconds..." if ENV['DEBUG']
              sleep 30
              client.reconnect rescue nil
            end
          end
        end
        
        puts "Socket Mode connection started" if ENV['DEBUG']
      rescue Slack::Web::Api::Errors::SlackError => e
        puts "Slack API error: #{e.message}"
      rescue => e
        puts "Socket Mode initialization error: #{e.message}"
        puts e.backtrace.join("\n") if ENV['DEBUG']
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
