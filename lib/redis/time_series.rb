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
      cmd 'TS.ADD', key, timestamp, value
    end

    def create
      args = [key]
      args << "RETENTION #{retention}" if retention
      args << "UNCOMPRESSED" if uncompressed
      args << "LABELS #{label_string}" if labels.any?
      cmd 'TS.CREATE', args
      self
    end

    def destroy
      redis.del key
    end

    def info
      cmd('TS.INFO', key).each_slice(2).reduce({}) do |h, (key, value)|
        h[key.gsub(/(.)([A-Z])/,'\1_\2').downcase] = value
        h
      end
    end

    def labels=(val)
      @labels = val
      cmd 'TS.ALTER', key, 'LABELS', label_string
    end

    # TODO: class method for adding to multiple time-series
    def madd(*values)
      if values.one? && values.first.is_a?(Hash)
        # Hash of timestamp => value pairs
        args = values.first.map { |ts, val| [key, ts, val] }.flatten
      elsif values.one? && values.first.is_a?(Array)
        # Array of values, no timestamps
        args = values.first.map { |val| [key, '*', val] }.flatten
      else
        # Values as individual arguments, no timestamps
        args = values.map { |val| [key, '*', val] }.flatten
      end
      cmd 'TS.MADD', args
    end

    def retention=(val)
      @retention = val.to_i
      cmd 'TS.ALTER', key, 'RETENTION', val.to_i
    end

    private

    def cmd(name, *args)
      puts "DEBUG: #{name} #{args.join(' ')}" if ENV['DEBUG']
      redis.call name, *args
    end

    def label_string
      labels.map { |label, value| "#{label} #{value}" }.join(' ')
    end
  end
end
