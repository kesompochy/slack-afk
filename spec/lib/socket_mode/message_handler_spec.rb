require 'spec_helper'
require_relative '../../../lib/socket_mode/message_handler'

RSpec.describe SocketMode::MessageHandler do
  let(:web_client) { instance_double(Slack::Web::Client) }
  let(:message_handler) { SocketMode::MessageHandler.new(web_client) }
  
  describe '#handle' do
    context 'with message events' do
      let(:event_data) do
        {
          'payload' => {
            'event' => {
              'type' => 'message',
              'text' => 'こんにちは <@U123456>',
              'user' => 'U654321',
              'channel' => 'C123456',
              'ts' => '1234567890.123456'
            }
          }
        }
      end

      before do
        # RedisConnectionのモック
        redis_pool = instance_double('Redis')
        allow(RedisConnection).to receive(:pool).and_return(redis_pool)
        allow(redis_pool).to receive(:lrange).with('registered', 0, -1).and_return(['U123456'])
        allow(redis_pool).to receive(:get).with('U123456').and_return('私は今離席中です')
        
        # App::Model::Storeのモック
        allow(App::Model::Store).to receive(:get).with('C123456').and_return({ 'enable' => 1 })
        allow(App::Model::Store).to receive(:get).with('U123456').and_return({ 'mention_histotry' => [] })
        allow(App::Model::Store).to receive(:set)
        
        # Slack Web Clientのモック
        allow(web_client).to receive(:chat_postMessage)
      end
      
      it 'processes mentions and sends automatic responses' do
        expect(web_client).to receive(:chat_postMessage).with(
          hash_including(
            channel: 'C123456',
            text: "自動応答: 私は今離席中です"
          )
        )
        
        message_handler.handle(event_data)
      end
      
      it 'saves mention history' do
        expect(App::Model::Store).to receive(:set).with(
          'U123456',
          hash_including(
            'mention_histotry' => array_including(
              hash_including(
                channel: 'C123456',
                user: 'U654321',
                text: 'こんにちは ',
                event_ts: '1234567890.123456'
              )
            )
          )
        )
        
        message_handler.handle(event_data)
      end
    end
    
    context 'with filtered message events' do
      it 'ignores channel_join subtype' do
        event_data = {
          'payload' => {
            'event' => {
              'type' => 'message',
              'subtype' => 'channel_join',
              'text' => '<@U123456> joined the channel',
              'user' => 'U654321',
              'channel' => 'C123456'
            }
          }
        }
        
        expect(RedisConnection.pool).not_to receive(:lrange)
        message_handler.handle(event_data)
      end
      
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
        
        expect(RedisConnection.pool).not_to receive(:lrange)
        message_handler.handle(event_data)
      end
      
      it 'ignores karma messages' do
        event_data = {
          'payload' => {
            'event' => {
              'type' => 'message',
              'text' => '<@U123456>++',
              'user' => 'U654321',
              'channel' => 'C123456'
            }
          }
        }
        
        expect(RedisConnection.pool).not_to receive(:lrange)
        message_handler.handle(event_data)
      end
    end
  end
end 
