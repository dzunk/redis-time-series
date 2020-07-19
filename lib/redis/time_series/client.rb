# frozen_string_literal: true
class Redis
  class TimeSeries
    module Client
      def self.extended(base)
        base.class_eval do
          attr_accessor :redis

          private

          def cmd(name, *args)
            self.class.send :cmd_with_redis, redis, name, *args
          end
        end
      end

      def debug
        @debug.nil? ? [true, 'true', 1].include?(ENV['DEBUG']) : @debug
      end

      def debug=(bool)
        @debug = !!bool
      end

      def redis
        @redis ||= Redis.current
      end

      def redis=(client)
        @redis = client
      end

      private

      def cmd(name, *args)
        cmd_with_redis redis, name, *args
      end

      def cmd_with_redis(redis, name, *args)
        args = args.flatten.compact.map { |arg| arg.is_a?(Time) ? arg.ts_msec : arg }
        puts "DEBUG: #{name} #{args.join(' ')}" if debug
        redis.call name, args
      end
    end
  end
end
