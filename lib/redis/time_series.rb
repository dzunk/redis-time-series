# frozen_string_literal: true
using TimeMsec

class Redis
  # 
  class TimeSeries
    extend Client
    extend Forwardable

    class << self
      # Create a new time series.
      #
      # @param key [String] the Redis key to store time series data in
      # @option options [Hash] :labels
      #   A hash of label-value pairs to apply to this series.
      # @option options [Redis] :redis (self.class.redis) a different Redis client to use
      # @option options [Integer] :retention
      #   Maximum age for samples compared to last event time (in milliseconds).
      #   With no value, the series will not be trimmed.
      # @option options [Boolean] :uncompressed
      #   When true, series data will be stored in an uncompressed format.
      #
      # @return [Redis::TimeSeries] the created time series
      # @see https://oss.redislabs.com/redistimeseries/commands/#tscreate
      def create(key, **options)
        new(key, redis: options.fetch(:redis, redis)).create(**options)
      end

      # Create a compaction rule for a series. Note that both source and destination series
      # must exist before the rule can be created.
      #
      # @param source [String, Redis::TimeSeries] the source series (or key) to apply the rule to
      # @param dest [String, Redis::TimeSeries] the destination series (or key) to aggregate the data
      # @param aggregation [Array(<String, Symbol>, Integer), Redis::TimeSeries::Aggregation]
      #   The aggregation to apply. Can be a {Redis::TimeSeries::Aggregation} object, or an array of
      #   aggregation_type and duration.
      #
      # @return [String] the string "OK"
      # @raise [Redis::TimeSeries::AggregationError] if the given aggregation params are invalid
      # @raise [Redis::CommandError] if the compaction rule cannot be applied to either series
      #
      # @see https://oss.redislabs.com/redistimeseries/commands/#tscreaterule
      def create_rule(source:, dest:, aggregation:)
        cmd 'TS.CREATERULE', key_for(source), key_for(dest), Aggregation.parse(aggregation).to_a
      end

      # Delete an existing compaction rule.
      #
      # @param source [String, Redis::TimeSeries] the source series (or key) to remove the rule from
      # @param dest [String, Redis::TimeSeries] the destination series (or key) the rule applies to
      #
      # @return [String] the string "OK"
      # @raise [Redis::CommandError] if the compaction rule does not exist
      def delete_rule(source:, dest:)
        cmd 'TS.DELETERULE', key_for(source), key_for(dest)
      end

      # Delete all data and remove a time series from Redis.
      # @param key [String] the key to remove
      # @return [1] if the series existed
      # @return [0] if the series did not exist
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

      # Search for a time series matching the provided filters. Refer to the {Filters} documentation
      # for more details on how to filter.
      #
      # @example Using a filter string
      #   Redis::TimeSeries.query_index('foo=bar')
      #   #=> [#<Redis::TimeSeries:0x00007ff00e222788 @key="ts3", @redis=#<Redis...>>]
      # @example Using the .where alias with hash DSL
      #   Redis::TimeSeries.where(foo: 'bar')
      #   #=> [#<Redis::TimeSeries:0x00007ff00e2a1d30 @key="ts3", @redis=#<Redis...>>]
      #
      # @param filter_value [Hash, String] a set of filters to query with
      # @return [Array<TimeSeries>] an array of series that matched the given filters
      #
      # @see Filters
      # @see https://oss.redislabs.com/redistimeseries/commands/#tsqueryindex
      # @see https://oss.redislabs.com/redistimeseries/commands/#filtering
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

    # @return [String] the Redis key this time series is stored in
    attr_reader :key

    def initialize(key, redis: self.class.redis)
      @key = key
      @redis = redis
    end

    # Add a value to the series.
    #
    # @param value [Numeric] the value to add
    # @param timestamp [Time, Numeric] the +Time+, or integer timestamp in milliseconds, to add the value
    # @param uncompressed [Boolean] if true, stores data in an uncompressed format
    #
    # @return [Sample] the value that was added
    # @raise [Redis::CommandError] if the value being added is older than the latest timestamp in the series
    def add(value, timestamp = '*', uncompressed: nil)
      ts = cmd 'TS.ADD', key, timestamp, value, ('UNCOMPRESSED' if uncompressed)
      Sample.new(ts, value)
    end

    # Issues a TS.CREATE command for the current series.
    # You should use class method {Redis::TimeSeries.create} instead.
    # @api private
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
    def_delegators :info, *Info.members - [:series] + %i[count length size source]

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

    # Compare series based on Redis key and configured client.
    # @return [Boolean] whether the two TimeSeries objects refer to the same series
    def ==(other)
      return false unless other.is_a?(self.class)
      key == other.key && redis == other.redis
    end
  end
end
