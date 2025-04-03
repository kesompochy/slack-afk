require 'spec_helper'
require_relative '../../../lib/socket_mode/client'

RSpec.describe SocketMode::Client do
  let(:client) { SocketMode::Client.new }
  
  describe '#initialize' do
    it 'creates web client and socket client' do
      expect(client.web_client).to be_a(Slack::Web::Client)
      expect(client.socket_client).to be_a(Slack::RealTime::Client)
    end
    
    it 'initializes a dispatcher with the web client' do
      expect(client.dispatcher).to be_a(SocketMode::Dispatcher)
    end
  end
  
  describe '#start' do
    it 'starts the socket client' do
      expect(client.socket_client).to receive(:start_async)
      client.start
    end
  end
  
  describe '#reconnect' do
    it 'restarts the socket client' do
      expect(client.socket_client).to receive(:start_async)
      client.reconnect
    end
  end
end 
