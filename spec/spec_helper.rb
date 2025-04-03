require 'rspec'
require 'webmock/rspec'
require 'vcr'
require 'mock_redis'

# テスト環境設定
ENV['RACK_ENV'] = 'test'
ENV['SLACK_BOT_TOKEN'] = 'xoxb-test-token'
ENV['SLACK_APP_TOKEN'] = 'xapp-test-token'

# 必要なファイルを読み込み
require_relative '../app'

# モック設定
WebMock.disable_net_connect!(allow_localhost: true)

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data('<SLACK_BOT_TOKEN>') { ENV['SLACK_BOT_TOKEN'] }
  config.filter_sensitive_data('<SLACK_APP_TOKEN>') { ENV['SLACK_APP_TOKEN'] }
end

RSpec.configure do |config|
  # rspec設定
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  Kernel.srand config.seed
end

# Redisのモック化
class MockRedisConnection
  def self.pool
    @redis ||= MockRedis.new
  end
end

# テスト用にRedisConnectionをモック化
RedisConnection = MockRedisConnection unless defined?(RedisConnection) 
