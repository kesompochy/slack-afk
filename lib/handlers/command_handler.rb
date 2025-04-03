module Handlers
  class CommandHandler
    def initialize(web_client)
      @web_client = web_client
    end
    
    def handle(data)
      payload = data['payload']
      command = payload['command']
      text = payload['text']
      channel_id = payload['channel_id']
      user_id = payload['user_id']
      
      puts "Received command: #{command} with text: #{text} from user: #{user_id} in channel: #{channel_id}"
      
      case command
      when '/afk'
        handle_afk_command(text, user_id, channel_id)
      when '/back'
        handle_back_command(user_id, channel_id)
      else
        puts "Unknown command: #{command}"
      end
    rescue => e
      puts "Error handling command: #{e.message}"
      puts e.backtrace.join("\n") if ENV['DEBUG']
    end
    
    private
    
    def handle_afk_command(text, user_id, channel_id)
      message = text.empty? ? "離席中" : text
      @web_client.chat_postMessage(
        channel: channel_id,
        text: "<@#{user_id}> がAFKになりました: #{message}"
      )
    end
    
    def handle_back_command(user_id, channel_id)
      @web_client.chat_postMessage(
        channel: channel_id,
        text: "<@#{user_id}> が戻りました！"
      )
    end
  end
end 
