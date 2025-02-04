require 'simplecov'
#SimpleCov.start { add_filter '/spec/' }

require 'bundler/setup'
require 'active_support/core_ext/numeric/time'
require 'active_support/testing/time_helpers'
require 'pry'
require 'redis'
require 'redis-time-series'

REDIS_PORT = ENV['REDIS_PORT'] || 9000
REDIS_HOST = ENV['REDIS_HOST'] || '127.0.0.1'
REDIS_PASSWORD = ENV['REDIS_PASSWORD'] || ""

module RedisHelpers
  def redis
    @redis ||= ConnectionPool.new(size: 25, timeout: 50) { Redis.new(host: REDIS_HOST,port: REDIS_PORT, password: REDIS_PASSWORD) }
  end
end

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = '.rspec_status'
  config.filter_run_when_matching :focus

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include RedisHelpers
  config.include ActiveSupport::Testing::TimeHelpers

  #config.before(:suite) { Redis.new.flushdb }
  config.before { Redis::TimeSeries.redis = redis }
end

RSpec::Matchers.define :issue_command do |expected|
  supports_block_expectations

  match do |actual|
    @commands = []
    allow_any_instance_of(Redis).to receive(:call).and_wrap_original do |redis, *args|
      @commands << args.join(' ')
      redis.call(*args)
    end

    allow_any_instance_of(Redis::PipelinedConnection).to receive(:call).and_wrap_original do |redis, *args|
      @commands << args.join(' ')
      redis.call(*args)
    end

    actual.call
    expect(@commands).to include(expected)
  end

  failure_message do |actual|
    "expected command #{expected}\n" \
      "received commands:\n" \
      "  #{@commands.join("\n  ")}"
  end
end
