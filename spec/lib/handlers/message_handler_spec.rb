require 'spec_helper'
require_relative '../../../lib/handlers/message_handler'

RSpec.describe Handlers::MessageHandler do
  let(:web_client) { instance_double(Slack::Web::Client) }
  let(:message_handler) { Handlers::MessageHandler.new(web_client) }
  
  before do
    allow(web_client).to receive(:chat_postMessage)
    # App::Registryのモック
    allow(App::Registry).to receive(:bot_token_client).and_return(nil)
    allow(App::Registry).to receive(:register)
    # テスト実行前にRedisをクリア
    RedisConnection.pool.flushdb
  end
  
  describe '#handle' do
    context '不在ユーザーへのメンションを含むメッセージ' do
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
        # 不在リストにユーザーを追加
        RedisConnection.pool.lpush('registered', 'U123456')
        # 不在メッセージを設定
        RedisConnection.pool.set('U123456', 'テストユーザーは席を外しています')
        # チャンネル情報を初期化
        App::Model::Store.set('C123456', { 'enable' => 1 })
        # メンション履歴を明示的に初期化
        user_presence = App::Model::Store.get('U123456')
        user_presence['mention_histotry'] = []
        App::Model::Store.set('U123456', user_presence)
      end
      
      it '不在ユーザーへの自動応答メッセージを送信する' do
        expect(web_client).to receive(:chat_postMessage).with(
          hash_including(
            channel: 'C123456',
            text: "自動応答: テストユーザーは席を外しています",
            thread_ts: '1234567890.123456'
          )
        )
        
        message_handler.handle(event_data)
      end
      
      it 'メンション履歴を保存する' do
        message_handler.handle(event_data)
        
        user_presence = App::Model::Store.get('U123456')
        expect(user_presence['mention_histotry']).to be_a(Array)
        expect(user_presence['mention_histotry'].size).to eq(1)
        expect(user_presence['mention_histotry'][0]['channel']).to eq('C123456')
        expect(user_presence['mention_histotry'][0]['user']).to eq('U654321')
        expect(user_presence['mention_histotry'][0]['text']).to eq('こんにちは ')
        expect(user_presence['mention_histotry'][0]['event_ts']).to eq('1234567890.123456')
      end
    end
    
    context 'スレッド内の不在ユーザーへのメンション' do
      let(:event_data) do
        {
          'payload' => {
            'event' => {
              'type' => 'message',
              'text' => 'スレッド内で <@U123456> にメンション',
              'user' => 'U654321',
              'channel' => 'C123456',
              'ts' => '1234567890.123457',
              'thread_ts' => '1234567890.123000'
            }
          }
        }
      end
      
      before do
        RedisConnection.pool.lpush('registered', 'U123456')
        RedisConnection.pool.set('U123456', 'テストユーザーは席を外しています')
        App::Model::Store.set('C123456', { 'enable' => 1 })
      end
      
      it 'スレッド内で自動応答する' do
        expect(web_client).to receive(:chat_postMessage).with(
          hash_including(
            channel: 'C123456',
            text: "自動応答: テストユーザーは席を外しています",
            thread_ts: '1234567890.123000'
          )
        )
        
        message_handler.handle(event_data)
      end
    end
    
    context '複数の不在ユーザーへのメンション' do
      let(:event_data) do
        {
          'payload' => {
            'event' => {
              'type' => 'message',
              'text' => '<@U123456> と <@U789012> に同時にメンション',
              'user' => 'U654321',
              'channel' => 'C123456',
              'ts' => '1234567890.123456'
            }
          }
        }
      end
      
      before do
        RedisConnection.pool.lpush('registered', 'U123456')
        RedisConnection.pool.lpush('registered', 'U789012')
        RedisConnection.pool.set('U123456', 'テストユーザー1は席を外しています')
        RedisConnection.pool.set('U789012', 'テストユーザー2は席を外しています')
        App::Model::Store.set('C123456', { 'enable' => 1 })
      end
      
      it '両方のユーザーに自動応答する' do
        expect(web_client).to receive(:chat_postMessage).with(
          hash_including(
            channel: 'C123456',
            text: "自動応答: テストユーザー1は席を外しています",
            thread_ts: '1234567890.123456'
          )
        )
        
        expect(web_client).to receive(:chat_postMessage).with(
          hash_including(
            channel: 'C123456',
            text: "自動応答: テストユーザー2は席を外しています",
            thread_ts: '1234567890.123456'
          )
        )
        
        message_handler.handle(event_data)
      end
    end
    
    context '無効化されたチャンネルでのメンション' do
      let(:event_data) do
        {
          'payload' => {
            'event' => {
              'type' => 'message',
              'text' => '<@U123456> へのメンション',
              'user' => 'U654321',
              'channel' => 'C123456',
              'ts' => '1234567890.123456'
            }
          }
        }
      end
      
      before do
        RedisConnection.pool.lpush('registered', 'U123456')
        RedisConnection.pool.set('U123456', 'テストユーザーは席を外しています')
        App::Model::Store.set('C123456', { 'enable' => 0 })
      end
      
      it '自動応答しない' do
        expect(web_client).not_to receive(:chat_postMessage)
        message_handler.handle(event_data)
      end
    end
    
    context 'ボットメッセージの場合' do
      let(:event_data) do
        {
          'payload' => {
            'event' => {
              'type' => 'message',
              'subtype' => 'bot_message',
              'text' => 'こんにちは <@U123456>',
              'user' => 'B654321',
              'channel' => 'C123456',
              'ts' => '1234567890.123456'
            }
          }
        }
      end
      
      before do
        RedisConnection.pool.lpush('registered', 'U123456')
        RedisConnection.pool.set('U123456', 'テストユーザーは席を外しています')
      end
      
      it 'ボットメッセージには反応しない' do
        expect(web_client).not_to receive(:chat_postMessage)
        message_handler.handle(event_data)
      end
    end
    
    context '不在登録されていないユーザーへのメンション' do
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
        # 不在リストを空にする
        RedisConnection.pool.del('registered')
        App::Model::Store.set('C123456', { 'enable' => 1 })
      end
      
      it '自動応答しない' do
        expect(web_client).not_to receive(:chat_postMessage)
        message_handler.handle(event_data)
      end
    end
    
    context '不正なデータ形式の場合' do
      it '空のペイロードで例外が発生しない' do
        expect { message_handler.handle({}) }.not_to raise_error
      end
      
      it 'イベントなしでも例外が発生しない' do
        expect { message_handler.handle({ 'payload' => {} }) }.not_to raise_error
      end
    end
  end
end 
