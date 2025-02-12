# frozen_string_literal: true

class Redis
  class TimeSeries
    # The client module handles connection management for individual time series, and
    # the parent {TimeSeries} class methods. You can enable or disable debugging, and set
    # a default Redis client to use for time series objects.
    module Client
      def self.extended(base)
        base.class_eval do
          attr_accessor(:redis)

          private

          def cmd(name, *args, pipeline: nil)
            self.class.send(:cmd_with_redis, redis, name, *args, pipeline: pipeline)
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
      def redis=(conn)
        $redis = conn # = TimeSeries::ConnectionPoolProxy.proxy_if_needed(conn)
      end

      def redis
        $redis ||
          raise(NotConnectedError, "Redis::TimeSeries.redis not set to a Redis.new connection")
      end

      private
        def cmd(name, *args, pipeline: nil)
          cmd_with_redis redis, name, *args, pipeline: pipeline
        end

        def cmd_with_redis(redis, name, *args, pipeline: nil)
          args = args.flatten.compact.map { |arg| arg.is_a?(Time) ? arg.to_i * 1000 : arg.to_s }
          puts "DEBUG: #{name} #{args.join(' ')}" if debug
          if pipeline
            pipeline.call name, args
          else
            redis.then { |c| c.call name, args }
          end
        end
    end
  end
end
