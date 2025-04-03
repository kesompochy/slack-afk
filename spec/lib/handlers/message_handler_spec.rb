require 'spec_helper'
require_relative '../../../lib/handlers/message_handler'

RSpec.describe Handlers::MessageHandler do
  let(:web_client) { instance_double(Slack::Web::Client) }
  let(:message_handler) { Handlers::MessageHandler.new(web_client) }
  
  before do
    allow(web_client).to receive(:chat_postMessage)
  end
  
  describe '#handle' do
    context 'with message events' do
      let(:event_data) do
        {
          'payload' => {
            'event' => {
              'type' => 'message',
              'text' => 'こんにちは',
              'user' => 'U654321',
              'channel' => 'C123456',
              'ts' => '1234567890.123456'
            }
          }
        }
      end
      
      it 'sends a response message' do
        expect(web_client).to receive(:chat_postMessage).with(
          hash_including(
            channel: 'C123456',
            text: "こんにちは <@U654321>！Socket Mode接続テスト中です :wave:",
            thread_ts: '1234567890.123456'
          )
        )
        
        message_handler.handle(event_data)
      end
    end
    
    context 'with app_mention events' do
      let(:event_data) do
        {
          'payload' => {
            'event' => {
              'type' => 'app_mention',
              'text' => '<@U123456> こんにちは',
              'user' => 'U654321',
              'channel' => 'C123456',
              'ts' => '1234567890.123456'
            }
          }
        }
      end
      
      it 'sends a response message' do
        expect(web_client).to receive(:chat_postMessage).with(
          hash_including(
            channel: 'C123456',
            text: "こんにちは <@U654321>！Socket Mode接続テスト中です :wave:",
            thread_ts: '1234567890.123456'
          )
        )
        
        message_handler.handle(event_data)
      end
    end
    
    context 'with thread reply' do
      let(:event_data) do
        {
          'payload' => {
            'event' => {
              'type' => 'message',
              'text' => 'スレッドの返信',
              'user' => 'U654321',
              'channel' => 'C123456',
              'ts' => '1234567890.123457',
              'thread_ts' => '1234567890.123456'
            }
          }
        }
      end
      
      it 'responds in the same thread' do
        expect(web_client).to receive(:chat_postMessage).with(
          hash_including(
            channel: 'C123456',
            thread_ts: '1234567890.123456'
          )
        )
        
        message_handler.handle(event_data)
      end
    end
    
    context 'with filtered message events' do
      it 'ignores bot_message subtype' do
        event_data = {
          'payload' => {
            'event' => {
              'type' => 'message',
              'subtype' => 'bot_message',
              'text' => 'Bot says: <@U123456>',
              'user' => 'U654321',
              'channel' => 'C123456'
            }
          }
        }
        
        expect(web_client).not_to receive(:chat_postMessage)
        message_handler.handle(event_data)
      end
      
      it 'ignores unsupported event types' do
        event_data = {
          'payload' => {
            'event' => {
              'type' => 'reaction_added',
              'user' => 'U654321',
              'channel' => 'C123456'
            }
          }
        }
        
        expect(web_client).not_to receive(:chat_postMessage)
        message_handler.handle(event_data)
      end
    end
    
    context 'with error conditions' do
      it 'handles missing payload gracefully' do
        event_data = {}
        expect { message_handler.handle(event_data) }.not_to raise_error
      end
    end
  end
end 
