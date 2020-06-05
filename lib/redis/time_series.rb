# frozen_string_literal: true
class Redis
  class TimeSeries
    class << self
      def create(key, **options)
        # TODO: TS.CREATE
        new(key, **options)
      end

    end

    attr_reader :redis

    def initialize(key, options = {})
      @key = key
      @redis = options[:redis] || Redis.current
    end
  end
end
