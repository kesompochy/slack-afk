require_relative '../handlers/message_handler'
require_relative '../handlers/command_handler'

module SocketMode
  class Dispatcher
    attr_reader :message_handler, :command_handler
    
    def initialize(web_client)
      @web_client = web_client
      @message_handler = Handlers::MessageHandler.new(web_client)
      @command_handler = Handlers::CommandHandler.new(web_client)
    end
    
    def dispatch_event(data)
      return unless data['payload'] && data['payload']['event']
      
      event_type = data['payload']['event']['type']
      puts "Dispatcherがイベントを処理: #{event_type}" if ENV['DEBUG']
      
      case event_type
      when 'message', 'app_mention'
        @message_handler.handle(data)
      else
        puts "Unsupported event type: #{event_type}" if ENV['DEBUG']
      end
    end
    
    def dispatch_command(data)
      @command_handler.handle(data)
    end
  end
end 
