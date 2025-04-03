module Handlers
  class MessageHandler
    def initialize(web_client)
      @web_client = web_client
    end
    
    def handle(event)
      puts "メッセージハンドラが呼ばれました: #{event.inspect}" if ENV['DEBUG']
      
      payload = event['payload']
      return unless payload && payload['event']
      
      message_event = payload['event']
      return if message_event['subtype'] == 'bot_message'
      
      event_type = message_event['type']
      return unless ['message', 'app_mention'].include?(event_type)
      
      channel = message_event['channel']
      text = message_event['text']
      user = message_event['user']
      thread_ts = message_event['thread_ts'] || message_event['ts']
      
      puts "メッセージ受信: channel=#{channel}, user=#{user}, text=#{text}" if ENV['DEBUG']
      
      @web_client.chat_postMessage(
        channel: channel,
        text: "こんにちは <@#{user}>！Socket Mode接続テスト中です :wave:",
        thread_ts: thread_ts
      )
      puts "メッセージ送信: channel=#{channel}"
    rescue => e
      puts "メッセージ処理エラー: #{e.message}"
      puts e.backtrace.join("\n") if ENV['DEBUG']
    end
  end
end 
