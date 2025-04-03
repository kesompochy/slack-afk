module Handlers
  class CommandHandler
    def initialize(web_client)
      @web_client = web_client
      setup_dependencies
    end
    
    def setup_dependencies
      require 'redis'
      require 'connection_pool'
      require_relative '../../app/registry'
      require_relative '../../app/libs/redis_connection'
      
      unless App::Registry.bot_token_client
        App::Registry.register(:bot_token_client, @web_client)
      end
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
      when '/lunch'
        handle_lunch_command(text, user_id, channel_id)
      when '/comeback'
        handle_comeback_command(text, user_id, channel_id)
      else
        puts "Unknown command: #{command}"
      end
    rescue => e
      puts "Error handling command: #{e.message}"
      puts e.backtrace.join("\n") if ENV['DEBUG']
    end
    
    private
    
    def handle_afk_command(text, user_id, channel_id)
      require_relative '../../app/mixins/slack_api_callable'
      require_relative '../../app/models/base'
      require_relative '../../app/models/afk'
      
      params = {
        "user_id" => user_id,
        "channel_id" => channel_id,
        "text" => text || "",
        "minute" => "",
        "user_name" => get_username_safe(user_id)
      }
      
      if text =~ /^(\d+)\s+(.*)$/
        params["minute"] = $1
        params["text"] = $2
      end
      
      afk = App::Model::Afk.new
      afk.bot_run(user_id, params)
    end
    
    def handle_lunch_command(text, user_id, channel_id)
      require_relative '../../app/mixins/slack_api_callable'
      require_relative '../../app/models/base'
      require_relative '../../app/models/lunch'
      
      params = {
        "user_id" => user_id,
        "channel_id" => channel_id,
        "text" => text || "",
        "user_name" => get_username_safe(user_id)
      }
      
      lunch = App::Model::Lunch.new
      lunch.bot_run(user_id, params)
    end
    
    def handle_comeback_command(text, user_id, channel_id)
      require_relative '../../app/mixins/slack_api_callable'
      require_relative '../../app/models/base'
      require_relative '../../app/models/store'
      require_relative '../../app/models/comeback'
      
      params = {
        "user_id" => user_id,
        "channel_id" => channel_id,
        "text" => text || "",
        "user_name" => get_username_safe(user_id)
      }
      
      comeback = App::Model::Comeback.new
      comeback.bot_run(user_id, params)
    end
    
    def get_username_safe(user_id)
      begin
        user_info = @web_client.users_info(user: user_id)
        user_info["ok"] ? user_info["user"]["name"] : user_id
      rescue => e
        puts "ユーザー情報取得エラー: #{e.message}" if ENV['DEBUG']
        user_id
      end
    end
  end
end 
