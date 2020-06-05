require 'bundler/setup'
require 'redis-time-series'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

RSpec::Matchers.define :issue_command do |expected|
  supports_block_expectations

  match do |actual|
    @commands = []
    allow(Redis.current).to receive(:call).and_wrap_original do |redis, *args|
      redis.call(*args)
      @commands << args.join(' ')
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
