module Handlers
  class CommandHandler
    def initialize(web_client)
      @web_client = web_client
    end
    
    def handle(data)
      command = data['payload']['command']
      puts "Received command: #{command}"
    rescue => e
      puts "Error handling command: #{e.message}"
    end
  end
end 
