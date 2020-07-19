# frozen_string_literal: true
using TimeMsec

class Redis
  class TimeSeries
    extend Client
    extend Forwardable

    class << self
      def create(key, **options)
        new(key, redis: options.fetch(:redis, redis)).create(**options)
      end

      def create_rule(source:, dest:, aggregation:)
        cmd 'TS.CREATERULE', key_for(source), key_for(dest), Aggregation.parse(aggregation).to_a
      end

      def delete_rule(source:, dest:)
        cmd 'TS.DELETERULE', key_for(source), key_for(dest)
      end

      def destroy(key)
        redis.del key
      end

      def madd(data)
        data.reduce([]) do |memo, (key, value)|
          memo << parse_madd_values(key, value)
          memo
        end.then do |args|
          cmd('TS.MADD', args).each_with_index.map do |result, idx|
            result.is_a?(Redis::CommandError) ? result : Sample.new(result, args[idx][2])
          end
        end
      end

      def query_index(filter_value)
        filters = Filters.new(filter_value)
        filters.validate!
        cmd('TS.QUERYINDEX', filters.to_a).map { |key| new(key) }
      end
      alias where query_index

      private

      def key_for(series_or_string)
        series_or_string.is_a?(self) ? series_or_string.key : series_or_string.to_s
      end

      def parse_madd_values(key, raw)
        if raw.is_a?(Hash) || (raw.is_a?(Array) && raw.first.is_a?(Array))
          # multiple timestamp => value pairs
          raw.map do |timestamp, value|
            [key, timestamp, value]
          end
        elsif raw.is_a? Array
          # single [timestamp, value]
          [key, raw.first, raw.last]
        else
          # single value, no timestamp
          [key, '*', raw]
        end
      end
    end

    attr_reader :key

    def initialize(key, redis: self.class.redis)
      @key = key
      @redis = redis
    end

    def add(value, timestamp = '*', uncompressed: nil)
      ts = cmd 'TS.ADD', key, timestamp, value, ('UNCOMPRESSED' if uncompressed)
      Sample.new(ts, value)
    end

    def create(retention: nil, uncompressed: nil, labels: nil)
      cmd 'TS.CREATE', key,
          (['RETENTION', retention] if retention),
          ('UNCOMPRESSED' if uncompressed),
          (['LABELS', labels.to_a] if labels&.any?)
      self
    end

    def create_rule(dest:, aggregation:)
      self.class.create_rule(source: self, dest: dest, aggregation: aggregation)
    end

    def delete_rule(dest:)
      self.class.delete_rule(source: self, dest: dest)
    end

    def decrby(value = 1, timestamp = nil, uncompressed: nil)
      cmd 'TS.DECRBY', key, value, (timestamp if timestamp), ('UNCOMPRESSED' if uncompressed)
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

    def incrby(value = 1, timestamp = nil, uncompressed: nil)
      cmd 'TS.INCRBY', key, value, (timestamp if timestamp), ('UNCOMPRESSED' if uncompressed)
    end
    alias increment incrby

    def info
      Info.parse series: self, data: cmd('TS.INFO', key)
    end
    def_delegators :info, *Info.members
    %i[count length size].each { |m| def_delegator :info, :total_samples, m }

    def labels=(val)
      cmd 'TS.ALTER', key, 'LABELS', val.to_a
    end

    def madd(*values)
      if values.one? && values.first.is_a?(Hash)
        # Hash of timestamp => value pairs
        args = values.first.map do |ts, val|
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

    def range(range, count: nil, aggregation: nil)
      if range.is_a?(Hash)
        # This is to support from: and to: passed in as hash keys
        # `range` will swallow all parameters if they're all hash syntax
        count = range.delete(:count)
        aggregation = range.delete(:aggregation)
        range = range.fetch(:from)..range.fetch(:to)
      end
      cmd('TS.RANGE',
          key,
          range.min,
          range.max,
          (['COUNT', count] if count),
          Aggregation.parse(aggregation)&.to_a
         ).map { |ts, val| Sample.new(ts, val) }
    end

    def retention=(val)
      cmd 'TS.ALTER', key, 'RETENTION', val.to_i
    end

    def ==(other)
      return false unless other.is_a?(self.class)
      key == other.key && redis == other.redis
    end
  end
end
