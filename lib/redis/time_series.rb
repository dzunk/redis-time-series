# frozen_string_literal: true
class Redis
  class TimeSeries
    class << self
      def create(key, **options)
        new(key, **options).create
      end

      def madd(data)
        data.reduce([]) do |memo, (key, value)|
          if value.is_a?(Hash) || (value.is_a?(Array) && value.first.is_a?(Array))
            # multiple timestamp => value pairs
            value.each do |timestamp, nested_value|
              timestamp = timestamp.ts_msec if timestamp.is_a? Time
              memo << [key, timestamp, nested_value]
            end
          elsif value.is_a? Array
            # single [timestamp, value]
            key = key.ts_msec if key.is_a? Time
            memo << [key, value]
          else
            # single value, no timestamp
            memo << [key, '*', value]
          end
          memo
        end.then do |args|
          puts "DEBUG: TS.MADD #{args.join(' ')}" if ENV['DEBUG']
          redis.call('TS.MADD', args.flatten).each_with_index.map do |result, idx|
            result.is_a?(Redis::CommandError) ? result : Sample.new(result, args[idx][2])
          end
        end
      end

      def redis
        @redis ||= Redis.current
      end

      def redis=(client)
        @redis = redis
      end
    end

    attr_reader :key, :labels, :redis, :retention, :uncompressed

    def initialize(key, options = {})
      @key = key
      # TODO: read labels from redis if not loaded in memory
      @labels = options[:labels] || []
      @redis = options[:redis] || self.class.redis
      @retention = options[:retention]
      @uncompressed = options[:uncompressed] || false
    end

    def add(value, timestamp = '*')
      timestamp = timestamp.ts_msec if timestamp.is_a? Time
      ts = cmd 'TS.ADD', key, timestamp, value
      Sample.new(ts, value)
    end

    def create
      args = [key]
      args << "RETENTION #{retention}" if retention
      args << "UNCOMPRESSED" if uncompressed
      args << "LABELS #{label_string}" if labels.any?
      cmd 'TS.CREATE', args
      self
    end

    def decrby(value = 1, timestamp = nil)
      args = [key, value]
      args << timestamp if timestamp
      cmd 'TS.DECRBY', args
    end
    alias decrement decrby

    def destroy
      redis.del key
    end

    def get
      cmd('TS.GET', key).then do |timestamp, value|
        return unless value
        Sample.new(timestamp, value)
      end
    end

    def incrby(value = 1, timestamp = nil)
      args = [key, value]
      args << timestamp if timestamp
      cmd 'TS.INCRBY', args
    end
    alias increment incrby

    # TODO: extract Info module, with methods for each property
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

    def madd(*values)
      if values.one? && values.first.is_a?(Hash)
        # Hash of timestamp => value pairs
        args = values.first.map do |ts, val|
          ts = ts.ts_msec if ts.is_a? Time
          [key, ts, val]
        end.flatten
      elsif values.one? && values.first.is_a?(Array)
        # Array of values, no timestamps
        initial_ts = Time.now.ts_msec
        args = values.first.each_with_index.map do |val, idx|
          [key, initial_ts + idx, val]
        end.flatten
      else
        # Values as individual arguments, no timestamps
        initial_ts = Time.now.ts_msec
        args = values.each_with_index.map do |val, idx|
          [key, initial_ts + idx, val]
        end.flatten
      end
      # TODO: return Sample objects here
      cmd 'TS.MADD', args
    end

    def range(range, count: nil, agg: nil)
      if range.is_a? Hash
        args = range.fetch(:from), range.fetch(:to)
      elsif range.is_a? Range
        args = range.min, range.max
      end
      args.map! { |ts| (ts.to_f * 1000).to_i }
      args.append('COUNT', count) if count
      args.append('AGGREGATION', agg) if agg
      cmd('TS.RANGE', key, args).map do |ts, val|
        Sample.new(ts, val)
      end
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
