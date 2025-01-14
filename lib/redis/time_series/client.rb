# frozen_string_literal: true

class Redis
  class TimeSeries
    # The client module handles connection management for individual time series, and
    # the parent {TimeSeries} class methods. You can enable or disable debugging, and set
    # a default Redis client to use for time series objects.
    module Client
      def self.extended(base)
        base.class_eval do
          attr_reader(:redis)

          private

          def cmd(name, *args)
            self.class.send(:cmd_with_redis, redis, name, *args)
          end
        end
      end

      # Check debug status. Defaults to on with +DEBUG=true+ environment variable.
      # @return [Boolean] current debug status
      def debug
        @debug.nil? ? [true, 'true', 1].include?(ENV['DEBUG']) : @debug
      end

      # Enable or disable debug output for time series commands. Enabling debug will
      # print commands to +STDOUT+ as they're executed.
      #
      # @example
      #   [1] pry(main)> @ts1.get
      #   => #<Redis::TimeSeries::Sample:0x00007fc82e9de150 @time=2020-07-19 15:01:13 -0700, @value=0.56e2>
      #   [2] pry(main)> Redis::TimeSeries.debug = true
      #   => true
      #   [3] pry(main)> @ts1.get
      #   DEBUG: TS.GET ts1
      #    => #<Redis::TimeSeries::Sample:0x00007fc82f11b7b0 @time=2020-07-19 15:01:13 -0700, @value=0.56e2>
      #
      # @return [Boolean] new debug status
      def debug=(bool)
        @debug = !!bool
      end

      # @return [Redis] the current Redis client. Defaults to +Redis.new+
      def redis
        @redis ||= Redis.new
      end

      # Set the default Redis client for time series objects.
      # This may be useful if you already use a non-time-series Redis database, and want
      # to use both at the same time.
      #
      # @example
      #   # config/initializers/redis_time_series.rb
      #   Redis::TimeSeries.redis = Redis.new(url: 'redis://my-redis-server:6379/0')
      #
      # @param client [Redis] a Redis client
      # @return [Redis]
      def redis=(client)
        @redis = client
      end

      private
        def cmd(name, *args)
          cmd_with_redis redis, name, *args
        end

        def cmd_with_redis(redis, name, *args)
          args = args.flatten.compact.map { |arg| arg.is_a?(Time) ? arg.to_i * 1000 : arg.to_s }
          puts "DEBUG: #{name} #{args.join(' ')}" if debug
          redis.call name, args
        end
    end
  end
end
