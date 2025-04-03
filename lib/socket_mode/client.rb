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
    end
    
    def start
      connect_socket
      
      @main_thread = Thread.current
      @running = true
    end
    
    def stop
      @running = false
      @ping_thread&.kill
      @ws.close if @ws && !@ws.closed?
      puts "Socket Modeクライアントを停止しました"
    end
    
    def reconnect
      stop
      sleep 1
      start
    end
    
    private
    
    def connect_socket
      begin
        app_client = Slack::Web::Client.new(token: ENV['SLACK_APP_TOKEN'])
        response = app_client.apps_connections_open
        
        unless response['ok']
          puts "Socket Mode URL取得に失敗: #{response['error'] || 'unknown error'}"
          return
        end
        
        wss_url = response['url']
        puts "Socket Mode URL取得: #{wss_url}"
        
        # クロージャでSocketClientインスタンスを参照するための変数
        client = self
        
        @ws = WebSocket::Client::Simple.connect(wss_url)
        ws_connection = @ws
        
        @ws.on :message do |msg|
          if msg.data.start_with?('Ping from')
            puts "Slackサーバーからのping: #{msg.data}" if ENV['DEBUG']
            next
          end
          
          begin
            data = JSON.parse(msg.data)
            puts "受信データ: #{data.inspect}" if ENV['DEBUG'] && data['type'] != 'hello'
            
            case data['type']
            when 'hello'
              puts "Socket Modeに接続しました"
            when 'disconnect'
              puts "切断要求を受信: #{data['reason']}"
              client.reconnect
            when 'events_api'
              client.send(:handle_events_api, data)
            when 'slash_commands'
              client.send(:handle_slash_commands, data)
            when 'interactive'
              puts "インタラクティブイベント受信" if ENV['DEBUG']
            else
              puts "未知のイベントタイプ: #{data['type']}" if ENV['DEBUG']
            end
            
            # イベント受信の確認応答
            if data['envelope_id']
              ack = { envelope_id: data['envelope_id'] }.to_json
              ws_connection.send(ack)
              puts "Acknowledge送信: #{data['envelope_id']}" if ENV['DEBUG']
            end
          rescue JSON::ParserError => e
            puts "JSONパースエラー: #{msg.data.inspect}"
          rescue => e
            puts "メッセージ処理エラー: #{e.message}"
            puts e.backtrace.join("\n") if ENV['DEBUG']
          end
        end
        
        @ws.on :error do |e|
          puts "WebSocketエラー: #{e.message}"
        end
        
        @ws.on :close do |e|
          puts "WebSocket切断: #{e.code} #{e.reason}"
          
          if client.instance_variable_get(:@running)
            puts "5秒後に再接続します..."
            sleep 5
            begin
              client.reconnect
            rescue => err
              puts "再接続中にエラーが発生しました: #{err.message}"
              puts "30秒後に再度試行します..."
              sleep 30
              client.reconnect rescue nil
            end
          end
        end
        
        start_ping_thread
        
        puts "Socket Mode接続を開始しました"
      rescue Slack::Web::Api::Errors::SlackError => e
        puts "Slack APIエラー: #{e.message}"
        puts "SLACK_APP_TOKENが有効か確認してください（xapp-で始まる必要があります）"
      rescue => e
        puts "Socket Mode初期化エラー: #{e.message}"
        puts e.backtrace.join("\n") if ENV['DEBUG']
      end
    end
    
    def start_ping_thread
      @ping_thread&.kill
      
      client = self
      @ping_thread = Thread.new do
        while client.instance_variable_get(:@running) && client.instance_variable_get(:@ws) && !client.instance_variable_get(:@ws).closed?
          begin
            client.instance_variable_get(:@ws).send({ type: 'ping' }.to_json)
          rescue Errno::EPIPE => e
            puts "Ping送信エラー: Broken pipe - WebSocket接続が切断されました"
            puts "自動的に再接続します..."
            client.reconnect
            break
          rescue => e
            puts "Ping送信エラー: #{e.message}"
            if e.message.include?('closed') || defined?(e.code)
              puts "WebSocket接続が閉じられています。再接続します..."
              client.reconnect
              break
            end
          end
          sleep 30
        end
      end
    end
    
    def handle_events_api(data)
      event_type = data.dig('payload', 'event', 'type')
      puts "イベント受信: #{event_type || 'unknown'}" if ENV['DEBUG']
      
      if ENV['DEBUG']
        event = data.dig('payload', 'event')
        if event
          puts "イベント情報:"
          puts "  タイプ: #{event['type']}"
          puts "  チャンネル: #{event['channel']}" if event['channel']
          puts "  ユーザー: #{event['user']}" if event['user']
          puts "  テキスト: #{event['text']}" if event['text']
        end
      end
      
      @dispatcher.dispatch_event(data)
    end
    
    def handle_slash_commands(data)
      command = data.dig('payload', 'command')
      puts "スラッシュコマンド受信: #{command || 'unknown'}" if ENV['DEBUG']
      @dispatcher.dispatch_command(data)
    end
  end
end 
