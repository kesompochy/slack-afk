module Handlers
  class MessageHandler
    def initialize(web_client)
      @web_client = web_client
      setup_dependencies
    end
    
    def setup_dependencies
      require 'redis'
      require 'connection_pool'
      require 'json'
      require_relative '../../app/registry'
      require_relative '../../app/libs/redis_connection'
      require_relative '../../app/models/store'
      
      unless App::Registry.bot_token_client
        App::Registry.register(:bot_token_client, @web_client)
      end
    end
    
    def handle(event)
      payload = event['payload']
      return unless payload && payload['event']
      
      message_event = payload['event']
      
      return if message_event['subtype'] == 'bot_message'
      return if message_event['subtype'] == 'channel_join'
      
      return if message_event['text'] =~ /\+\+|is up to [0-9]+ points!/
      
      event_type = message_event['type']
      return unless ['message', 'app_mention'].include?(event_type)
      
      channel = message_event['channel']
      text = message_event['text']
      user = message_event['user']
      thread_ts = message_event['thread_ts'] || message_event['ts']
      
      entries = RedisConnection.pool.lrange('registered', 0, -1)
      
      mentioned_users = entries.select do |entry|
        text =~ /<@#{entry}>/
      end
      
      cid = channel
      c = App::Model::Store.get(cid)
      
      mentioned_users.each do |uid|
        message = RedisConnection.pool.get(uid)
        
        next unless message && c.fetch('enable', 1) == 1
        
        user_presence = App::Model::Store.get(uid)
        
        user_presence['mention_histotry'] ||= []
        user_presence['mention_histotry'] = [] if user_presence['mention_histotry'].is_a?(Hash)
        
        user_presence['mention_histotry'] << {
          channel: channel,
          user: user,
          text: text && text.gsub(/<@#{uid}>/, ''),
          event_ts: message_event['ts']
        }
        
        App::Model::Store.set(uid, user_presence)
        
        @web_client.chat_postMessage(
          channel: channel,
          text: "自動応答: #{message}",
          thread_ts: thread_ts
        )
      end
    rescue => e
      puts "Message processing error: #{e.message}"
    end
  end
end 
