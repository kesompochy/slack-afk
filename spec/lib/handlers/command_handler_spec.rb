require 'spec_helper'
require_relative '../../../lib/handlers/command_handler'

RSpec.describe Handlers::CommandHandler do
  let(:web_client) { instance_double(Slack::Web::Client) }
  let(:command_handler) { Handlers::CommandHandler.new(web_client) }
  
  before do
    allow(web_client).to receive(:chat_postMessage)
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
      
      it 'sends the correct afk message' do
        expect(web_client).to receive(:chat_postMessage).with(
          hash_including(
            channel: 'C123456',
            text: "<@U123456> がAFKになりました: 会議中"
          )
        )
        
        command_handler.handle(command_data)
      end
      
      it 'uses default message when text is empty' do
        command_data['payload']['text'] = ''
        
        expect(web_client).to receive(:chat_postMessage).with(
          hash_including(
            channel: 'C123456',
            text: "<@U123456> がAFKになりました: 離席中"
          )
        )
        
        command_handler.handle(command_data)
      end
    end
    
    context 'with /back command' do
      let(:command_data) do
        {
          'payload' => {
            'command' => '/back',
            'text' => '',
            'channel_id' => 'C123456',
            'user_id' => 'U123456'
          }
        }
      end
      
      it 'sends the correct back message' do
        expect(web_client).to receive(:chat_postMessage).with(
          hash_including(
            channel: 'C123456',
            text: "<@U123456> が戻りました！"
          )
        )
        
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
      
      it 'does not send any message' do
        expect(web_client).not_to receive(:chat_postMessage)
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
