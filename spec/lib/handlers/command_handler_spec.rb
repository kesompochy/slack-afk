require 'spec_helper'
require_relative '../../../lib/handlers/command_handler'

RSpec.describe Handlers::CommandHandler do
  let(:web_client) { instance_double(Slack::Web::Client) }
  let(:command_handler) { Handlers::CommandHandler.new(web_client) }
  
  before do
    allow(web_client).to receive(:users_info).with(any_args).and_return({"ok" => true, "user" => {"name" => "testuser"}})
    allow(web_client).to receive(:chat_postMessage)
    
    afk_instance = instance_double("App::Model::Afk")
    allow(afk_instance).to receive(:bot_run).and_return("AFK message")
    allow(App::Model::Afk).to receive(:new).and_return(afk_instance)
    
    comeback_instance = instance_double("App::Model::Comeback")
    allow(comeback_instance).to receive(:bot_run).and_return("Comeback message")
    allow(App::Model::Comeback).to receive(:new).and_return(comeback_instance)
  end
  
  describe '#handle' do
    context 'with /afk command' do
      let(:command_data) do
        {
          'payload' => {
            'command' => '/afk',
            'text' => '会議中',
            'channel_id' => 'C123456',
            'user_id' => 'U123456'
          }
        }
      end
      
      it 'calls handle_afk_command' do
        expect(command_handler).to receive(:handle_afk_command).with('会議中', 'U123456', 'C123456')
        command_handler.handle(command_data)
      end
    end
    
    context 'with /comeback command' do
      let(:command_data) do
        {
          'payload' => {
            'command' => '/comeback',
            'text' => '',
            'channel_id' => 'C123456',
            'user_id' => 'U123456'
          }
        }
      end
      
      it 'calls handle_comeback_command' do
        expect(command_handler).to receive(:handle_comeback_command).with('', 'U123456', 'C123456')
        command_handler.handle(command_data)
      end
    end
    
    context 'with unknown command' do
      let(:command_data) do
        {
          'payload' => {
            'command' => '/unknown',
            'text' => 'test',
            'channel_id' => 'C123456',
            'user_id' => 'U123456'
          }
        }
      end
      
      it 'does not call any handle commands' do
        expect(command_handler).not_to receive(:handle_afk_command)
        expect(command_handler).not_to receive(:handle_comeback_command)
        command_handler.handle(command_data)
      end
    end
    
    context 'with error in payload' do
      let(:invalid_data) do
        {
          'payload' => {}
        }
      end
      
      it 'handles errors gracefully' do
        expect { command_handler.handle(invalid_data) }.not_to raise_error
      end
    end
  end
end 
