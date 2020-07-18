# frozen_string_literal: true
using TimeMsec

class Redis
  class TimeSeries
    extend Forwardable

    class << self
      def create(key, **options)
        new(key, **options).create(labels: options[:labels])
      end

      def create_rule(source:, dest:, aggregation:)
        args = [
          source.is_a?(self) ? source.key : source.to_s,
          dest.is_a?(self) ? dest.key : dest.to_s,
          Aggregation.parse(aggregation).to_a
        ]
        redis.call 'TS.CREATERULE', *args.flatten
      end

      def delete_rule(source:, dest:)
        args = [
          source.is_a?(self) ? source.key : source.to_s,
          dest.is_a?(self) ? dest.key : dest.to_s
        ]
        redis.call 'TS.DELETERULE', *args
      end

      def destroy(key)
        redis.del key
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

      def query_index(filter_value)
        filters = Filters.new(filter_value)
        filters.validate!
        puts "DEBUG: TS.QUERYINDEX #{filters.to_a.join(' ')}" if ENV['DEBUG']
        redis.call('TS.QUERYINDEX', *filters.to_a).map { |key| new(key) }
      end
      alias where query_index

      def redis
        @redis ||= Redis.current
      end

      def redis=(client)
        @redis = redis
      end
    end

    attr_reader :key, :redis, :retention, :uncompressed

    def initialize(key, options = {})
      @key = key
      @redis = options[:redis] || self.class.redis
      @retention = options[:retention]
      @uncompressed = options[:uncompressed] || false
    end

    def add(value, timestamp = '*')
      timestamp = timestamp.ts_msec if timestamp.is_a? Time
      ts = cmd 'TS.ADD', key, timestamp, value
      Sample.new(ts, value)
    end

    def create(labels: nil)
      args = [key]
      args << ['RETENTION', retention] if retention
      args << 'UNCOMPRESSED' if uncompressed
      args << ['LABELS', labels.to_a] if labels&.any?
      cmd 'TS.CREATE', args.flatten
      self
    end

    def create_rule(dest:, aggregation:)
      self.class.create_rule(source: self, dest: dest, aggregation: aggregation)
    end

    def delete_rule(dest:)
      self.class.delete_rule(source: self, dest: dest)
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

    def info
      cmd('TS.INFO', key).then(&Info.method(:parse))
    end
    def_delegators :info, *Info.members
    %i[count length size].each { |m| def_delegator :info, :total_samples, m }

    def labels=(val)
      cmd 'TS.ALTER', key, 'LABELS', val.to_a.flatten
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
  end
end
