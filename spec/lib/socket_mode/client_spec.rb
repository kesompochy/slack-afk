require 'spec_helper'
require_relative '../../../lib/socket_mode/client'

RSpec.describe SocketMode::Client do
  let(:client) { SocketMode::Client.new }
  
  describe '#initialize' do
    it 'creates web client' do
      expect(client.web_client).to be_a(Slack::Web::Client)
    end
    
    it 'initializes a dispatcher with the web client' do
      expect(client.dispatcher).to be_a(SocketMode::Dispatcher)
    end
  end
  
  describe '#start' do
    before do
      allow(client).to receive(:connect_socket)
    end
    
    it 'sets the running flag' do
      client.start
      expect(client.instance_variable_get(:@running)).to be true
    end
  end
  
  describe '#stop' do
    let(:ws_mock) { double('WebSocket') }
    
    before do
      allow(ws_mock).to receive(:closed?).and_return(false)
      allow(ws_mock).to receive(:close)
      client.instance_variable_set(:@ws, ws_mock)
      client.instance_variable_set(:@running, true)
    end
    
    it 'closes the websocket connection' do
      expect(ws_mock).to receive(:close)
      client.stop
      expect(client.instance_variable_get(:@running)).to be false
    end
  end
  
  describe '#reconnect' do
    it 'calls stop and start' do
      expect(client).to receive(:stop)
      expect(client).to receive(:start)
      client.reconnect
    end
  end
end 
