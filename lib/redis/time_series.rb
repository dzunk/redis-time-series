# frozen_string_literal: true
class Redis
  class TimeSeries
    class << self
      def create(key, **options)
        new(key, **options).create
      end

    end

    attr_reader :key, :labels, :redis, :retention, :uncompressed

    def initialize(key, options = {})
      @key = key
      @labels = options[:labels] || []
      @redis = options[:redis] || Redis.current
      @retention = options[:retention]
      @uncompressed = options[:uncompressed] || false
    end

    def add(value, timestamp = '*')
      redis.call 'TS.ADD', key, timestamp, value
    end

    def create
      args = [key]
      args << "RETENTION #{retention}" if retention
      args << "UNCOMPRESSED" if uncompressed
      args << "LABELS #{label_string}" if labels.any?
      redis.call 'TS.CREATE', args
      self
    end

    def destroy
      redis.del key
    end

    def info

    end

    def labels=(val)
      @labels = val
      redis.call 'TS.ALTER', key, 'LABELS', label_string
    end

    def retention=(val)
      @retention = val.to_i
      redis.call 'TS.ALTER', key, 'RETENTION', val.to_i
    end

    private

    def label_string
      labels.map { |label, value| "#{label} #{value}" }.join(' ')
    end
  end
end
