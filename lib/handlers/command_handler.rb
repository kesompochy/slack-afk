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
      
      puts "Received command: #{command} with text: #{text} from user: #{user_id} in channel: #{channel_id}" if ENV['DEBUG']
      
      case command
      when '/afk'
        handle_afk_command(text, user_id, channel_id)
      when '/lunch', '/afk_lunch'
        handle_lunch_command(text, user_id, channel_id)
      when '/comeback', '/afk_comeback'
        handle_comeback_command(text, user_id, channel_id)
      when '/finish', '/end', '/afk_end'
        handle_finish_command(text, user_id, channel_id)
      when '/start', '/afk_start'
        handle_start_command(text, user_id, channel_id)
      when '/enable_afk', '/afk_enable'
        handle_enable_afk_command(text, user_id, channel_id)
      when '/disable_afk', '/afk_disable'
        handle_disable_afk_command(text, user_id, channel_id)
      when %r{^/afk_([0-9]+)}
        minutes = $1
        handle_timed_afk_command(text, user_id, channel_id, minutes)
      else
        puts "Unknown command: #{command}" if ENV['DEBUG']
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
      afk.run(user_id, params)
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
      lunch.run(user_id, params)
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
      comeback.run(user_id, params)
    end
    
    def handle_finish_command(text, user_id, channel_id)
      require_relative '../../app/mixins/slack_api_callable'
      require_relative '../../app/models/base'
      require_relative '../../app/models/store'
      require_relative '../../app/models/finish'
      
      params = {
        "user_id" => user_id,
        "channel_id" => channel_id,
        "text" => text || "",
        "user_name" => get_username_safe(user_id)
      }
      
      finish = App::Model::Finish.new
      finish.run(user_id, params)
    end
    
    def handle_start_command(text, user_id, channel_id)
      require_relative '../../app/mixins/slack_api_callable'
      require_relative '../../app/models/base'
      require_relative '../../app/models/store'
      require_relative '../../app/models/start'
      
      params = {
        "user_id" => user_id,
        "channel_id" => channel_id,
        "text" => text || "",
        "user_name" => get_username_safe(user_id)
      }
      
      start = App::Model::Start.new
      start.run(user_id, params)
    end
    
    def handle_enable_afk_command(text, user_id, channel_id)
      require_relative '../../app/mixins/slack_api_callable'
      require_relative '../../app/models/store'
      
      c = App::Model::Store.get(channel_id)
      c['enable'] = 1
      App::Model::Store.set(channel_id, c)
      
      @web_client.chat_postMessage(
        channel: channel_id,
        text: "このチャンネルでの代理応答を有効にしました",
        as_user: true
      )
    end
    
    def handle_disable_afk_command(text, user_id, channel_id)
      require_relative '../../app/mixins/slack_api_callable'
      require_relative '../../app/models/store'
      
      c = App::Model::Store.get(channel_id)
      c['enable'] = 0
      App::Model::Store.set(channel_id, c)
      
      @web_client.chat_postMessage(
        channel: channel_id,
        text: "このチャンネルでの代理応答を無効にしました",
        as_user: true
      )
    end
    
    def handle_timed_afk_command(text, user_id, channel_id, minutes)
      require_relative '../../app/mixins/slack_api_callable'
      require_relative '../../app/models/base'
      require_relative '../../app/models/afk'
      
      params = {
        "user_id" => user_id,
        "channel_id" => channel_id,
        "text" => text || "",
        "minute" => minutes,
        "user_name" => get_username_safe(user_id)
      }
      
      afk = App::Model::Afk.new
      afk.run(user_id, params)
    end
    
    def get_username_safe(user_id)
      begin
        user_info = @web_client.users_info(user: user_id)
        user_info["ok"] ? user_info["user"]["name"] : user_id
      rescue => e
        puts "Error getting user info: #{e.message}"
        user_id
      end
    end
  end
end 
