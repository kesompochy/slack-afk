require 'spec_helper'
require_relative '../../../lib/socket_mode/dispatcher'

RSpec.describe SocketMode::Dispatcher do
  let(:web_client) { instance_double(Slack::Web::Client) }
  let(:dispatcher) { SocketMode::Dispatcher.new(web_client) }
  
  describe '#initialize' do
    it 'sets up message and command handlers' do
      expect(dispatcher.message_handler).to be_a(Handlers::MessageHandler)
      expect(dispatcher.command_handler).to be_a(Handlers::CommandHandler)
    end
  end
  
  describe '#dispatch_event' do
    let(:message_event) do
      {
        'type' => 'events_api',
        'payload' => {
          'event' => {
            'type' => 'message',
            'text' => 'Hello!'
          }
        }
      }
    end
    
    let(:reaction_event) do
      {
        'type' => 'events_api',
        'payload' => {
          'event' => {
            'type' => 'reaction_added'
          }
        }
      }
    end
    
    it 'routes message events to message handler' do
      expect(dispatcher.message_handler).to receive(:handle)
      dispatcher.dispatch_event(message_event)
    end
    
    it 'ignores unsupported event types' do
      expect(dispatcher.message_handler).not_to receive(:handle)
      dispatcher.dispatch_event(reaction_event)
    end
  end
  
  describe '#dispatch_command' do
    let(:command_event) do
      {
        'type' => 'slash_commands',
        'payload' => {
          'command' => '/afk',
          'text' => 'out for lunch'
        }
      }
    end
    
    it 'routes command events to command handler' do
      expect(dispatcher.command_handler).to receive(:handle)
      dispatcher.dispatch_command(command_event)
    end
  end
end 
