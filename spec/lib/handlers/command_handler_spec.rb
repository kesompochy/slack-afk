require 'spec_helper'
require_relative '../../../lib/handlers/command_handler'

RSpec.describe Handlers::CommandHandler do
  let(:web_client) { instance_double("Slack::Web::Client") }
  let(:user_id) { "U123456" }
  let(:channel_id) { "C654321" }
  let(:text) { "test message" }
  let(:handler) { described_class.new(web_client) }
  
  before do
    allow(handler).to receive(:setup_dependencies)
    allow(web_client).to receive(:users_info).and_return({ "ok" => true, "user" => { "name" => "test_user" } })
    allow(App::Registry).to receive(:bot_token_client).and_return(nil)
    allow(App::Registry).to receive(:register)
    stub_const("ENV", { "DEBUG" => "true" })
  end
  
  describe "#handle" do
    let(:afk_model) { instance_double("App::Model::Afk") }
    let(:lunch_model) { instance_double("App::Model::Lunch") }
    let(:comeback_model) { instance_double("App::Model::Comeback") }
    let(:finish_model) { instance_double("App::Model::Finish") }
    let(:start_model) { instance_double("App::Model::Start") }
    
    before do
      allow(App::Model::Afk).to receive(:new).and_return(afk_model)
      allow(App::Model::Lunch).to receive(:new).and_return(lunch_model)
      allow(App::Model::Comeback).to receive(:new).and_return(comeback_model)
      allow(App::Model::Finish).to receive(:new).and_return(finish_model)
      allow(App::Model::Start).to receive(:new).and_return(start_model)
      allow(afk_model).to receive(:run)
      allow(lunch_model).to receive(:run)
      allow(comeback_model).to receive(:run)
      allow(finish_model).to receive(:run)
      allow(start_model).to receive(:run)
      allow(App::Model::Store).to receive(:get).and_return({})
      allow(App::Model::Store).to receive(:set)
      allow(web_client).to receive(:chat_postMessage)
    end
    
    it "handles afk command" do
      data = {
        "payload" => {
          "command" => "/afk",
          "text" => text,
          "channel_id" => channel_id,
          "user_id" => user_id
        }
      }
      
      expect(afk_model).to receive(:run).with(user_id, hash_including("text" => text))
      handler.handle(data)
    end
    
    it "handles lunch command" do
      data = {
        "payload" => {
          "command" => "/lunch",
          "text" => text,
          "channel_id" => channel_id,
          "user_id" => user_id
        }
      }
      
      expect(lunch_model).to receive(:run).with(user_id, hash_including("text" => text))
      handler.handle(data)
    end
    
    it "handles comeback command" do
      data = {
        "payload" => {
          "command" => "/comeback",
          "text" => text,
          "channel_id" => channel_id,
          "user_id" => user_id
        }
      }
      
      expect(comeback_model).to receive(:run).with(user_id, hash_including("text" => text))
      handler.handle(data)
    end
    
    it "handles finish command" do
      data = {
        "payload" => {
          "command" => "/finish",
          "text" => text,
          "channel_id" => channel_id,
          "user_id" => user_id
        }
      }
      
      expect(finish_model).to receive(:run).with(user_id, hash_including("text" => text))
      handler.handle(data)
    end
    
    it "handles end command as an alias for finish" do
      data = {
        "payload" => {
          "command" => "/end",
          "text" => text,
          "channel_id" => channel_id,
          "user_id" => user_id
        }
      }
      
      expect(finish_model).to receive(:run).with(user_id, hash_including("text" => text))
      handler.handle(data)
    end
    
    it "handles afk_end command as an alias for finish" do
      data = {
        "payload" => {
          "command" => "/afk_end",
          "text" => text,
          "channel_id" => channel_id,
          "user_id" => user_id
        }
      }
      
      expect(finish_model).to receive(:run).with(user_id, hash_including("text" => text))
      handler.handle(data)
    end
    
    it "handles start command" do
      data = {
        "payload" => {
          "command" => "/start",
          "text" => text,
          "channel_id" => channel_id,
          "user_id" => user_id
        }
      }
      
      expect(start_model).to receive(:run).with(user_id, hash_including("text" => text))
      handler.handle(data)
    end
    
    it "handles afk_start command as an alias for start" do
      data = {
        "payload" => {
          "command" => "/afk_start",
          "text" => text,
          "channel_id" => channel_id,
          "user_id" => user_id
        }
      }
      
      expect(start_model).to receive(:run).with(user_id, hash_including("text" => text))
      handler.handle(data)
    end
    
    it "handles enable_afk command" do
      data = {
        "payload" => {
          "command" => "/enable_afk",
          "text" => text,
          "channel_id" => channel_id,
          "user_id" => user_id
        }
      }
      
      expect(App::Model::Store).to receive(:get).with(channel_id).and_return({})
      expect(App::Model::Store).to receive(:set).with(channel_id, {'enable' => 1})
      expect(web_client).to receive(:chat_postMessage).with(
        hash_including(
          channel: channel_id,
          text: "このチャンネルでの代理応答を有効にしました"
        )
      )
      
      handler.handle(data)
    end
    
    it "handles disable_afk command" do
      data = {
        "payload" => {
          "command" => "/disable_afk",
          "text" => text,
          "channel_id" => channel_id,
          "user_id" => user_id
        }
      }
      
      expect(App::Model::Store).to receive(:get).with(channel_id).and_return({})
      expect(App::Model::Store).to receive(:set).with(channel_id, {'enable' => 0})
      expect(web_client).to receive(:chat_postMessage).with(
        hash_including(
          channel: channel_id,
          text: "このチャンネルでの代理応答を無効にしました"
        )
      )
      
      handler.handle(data)
    end
    
    it "handles afk_(number) command" do
      data = {
        "payload" => {
          "command" => "/afk_30",
          "text" => text,
          "channel_id" => channel_id,
          "user_id" => user_id
        }
      }
      
      expect(afk_model).to receive(:run).with(user_id, hash_including("minute" => "30"))
      handler.handle(data)
    end
  end
end 
