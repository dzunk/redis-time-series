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
      redis.call('TS.INFO', key).each_slice(2).reduce({}) do |h, (key, value)|
        h[key.gsub(/(.)([A-Z])/,'\1_\2').downcase] = value
        h
      end
    end

    def labels=(val)
      @labels = val
      redis.call 'TS.ALTER', key, 'LABELS', label_string
    end

    # TODO: class method for adding to multiple time-series
    def madd(*values)
      if values.one?
        args = values.first.map { |ts, val| [key, ts, val] }.flatten
      else
        args = values.map { |val| [key, '*', val] }.flatten
      end
      redis.call 'TS.MADD', args
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
