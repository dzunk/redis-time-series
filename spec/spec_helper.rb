require 'bundler/setup'
require 'active_support/core_ext/numeric/time'
require 'active_support/testing/time_helpers'
require 'pry'
require 'redis'
require 'redis-time-series'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = '.rspec_status'
  config.filter_run_when_matching :focus

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include ActiveSupport::Testing::TimeHelpers

  config.before(:suite) { Redis.current.flushdb }
end

RSpec::Matchers.define :issue_command do |expected|
  supports_block_expectations

  match do |actual|
    @commands = []
    allow(Redis.current).to receive(:call).and_wrap_original do |redis, *args|
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
