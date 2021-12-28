# frozen_string_literal: true
using TimeMsec

class Redis
  # The +Redis::TimeSeries+ class is an interface for working with time-series data in
  # Redis, using the {https://oss.redislabs.com/redistimeseries RedisTimeSeries} module.
  #
  # You can't use this gem with vanilla Redis, the time series module must be compiled
  # and loaded. The easiest way to do this is by running the provided Docker container.
  # Refer to the {https://oss.redislabs.com/redistimeseries/#setup setup guide} for more info.
  #
  # +docker run -p 6379:6379 -it --rm redislabs/redistimeseries+
  #
  # Once you're up and running, you can create a new time series and start recording data.
  # Many commands are documented below, but you should refer to the
  # {https://oss.redislabs.com/redistimeseries/commands command documentation} for the most
  # authoritative and up-to-date reference.
  #
  # @example
  #   ts = Redis::TimeSeries.create('time_series_example')
  #   ts.add(12345)
  #   ts.get
  #   #=> #<Redis::TimeSeries::Sample:0x00007ff00d942e60 @time=2020-07-19 16:52:48 -0700, @value=0.12345e5>
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
      # @option options [String, Symbol] :duplicate_policy
      #   A duplication policy to resolve conflicts when adding values to the series.
      #   Valid values are in Redis::TimeSeries::DuplicatePolicy::VALID_POLICIES
      # @option options [Integer] :chunk_size
      #   Amount of memory, in bytes, to allocate for each chunk of data. Must be a multiple
      #   of 8. Default for a series is 4096.
      #
      # @return [Redis::TimeSeries] the created time series
      # @see https://oss.redislabs.com/redistimeseries/commands/#tscreate
      def create(key, **options)
        new(key, redis: options.fetch(:redis, redis)).create(**options)
      end

      # Create a compaction rule for a series. Note that both source and destination series
      # must exist before the rule can be created.
      #
      # @param source [String, TimeSeries] the source series (or key) to apply the rule to
      # @param dest [String, TimeSeries] the destination series (or key) to aggregate the data
      # @param aggregation [Array(<String, Symbol>, Integer), Aggregation]
      #   The aggregation to apply. Can be an {Aggregation} object, or an array of
      #   aggregation_type and duration +[:avg, 120000]+
      #
      # @return [String] the string "OK"
      # @raise [Redis::TimeSeries::AggregationError] if the given aggregation params are invalid
      # @raise [Redis::CommandError] if the compaction rule cannot be applied to either series
      #
      # @see TimeSeries#create_rule
      # @see https://oss.redislabs.com/redistimeseries/commands/#tscreaterule
      def create_rule(source:, dest:, aggregation:)
        cmd 'TS.CREATERULE', key_for(source), key_for(dest), Aggregation.parse(aggregation).to_a
      end

      # Delete an existing compaction rule.
      #
      # @param source [String, TimeSeries] the source series (or key) to remove the rule from
      # @param dest [String, TimeSeries] the destination series (or key) the rule applies to
      #
      # @return [String] the string "OK"
      # @raise [Redis::CommandError] if the compaction rule does not exist
      def delete_rule(source:, dest:)
        cmd 'TS.DELETERULE', key_for(source), key_for(dest)
      end

      # Delete all data and remove a time series from Redis.
      #
      # @param key [String] the key to remove
      # @return [1] if the series existed
      # @return [0] if the series did not exist
      def destroy(key)
        redis.del key
      end

      # Add multiple values to multiple series.
      #
      # @example Adding multiple values with timestamps
      #   Redis::TimeSeries.madd(
      #     foo: { 2.minutes.ago => 123, 1.minute.ago => 456, Time.current => 789) },
      #     bar: { 2.minutes.ago => 987, 1.minute.ago => 654, Time.current => 321) }
      #   )
      # @example Adding multiple values without timestamps
      #   Redis::TimeSeries.madd(foo: 1, bar: 2, baz: 3)
      #
      # @param data [Hash] A hash of key-value pairs, with the key being the name of
      #   the series, and the value being a single scalar value or a nested hash
      #   of timestamp => value pairs
      # @return [Array<Sample, Redis::CommandError>] an array of the resulting samples
      #   added, or a CommandError if the sample in question could not be added to the
      #   series
      #
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
      alias multi_add madd
      alias add_multiple madd

      # Query across multiple series, returning values from oldest to newest.
      #
      # @param range [Range] A time range over which to query. Beginless and endless ranges
      #   indicate oldest and most recent timestamp, respectively.
      # @param filter [Hash, String] a set of filters to query with. Refer to the {Filters}
      #   documentation for more details on how to filter.
      # @param count [Integer] The maximum number of results to return for each series.
      # @param aggregation [Array(<String, Symbol>, Integer), Aggregation]
      #   The aggregation to apply. Can be an {Aggregation} object, or an array of
      #   aggregation_type and duration +[:avg, 120000]+
      # @param with_labels [Boolean] Whether to return the label details of the matched
      #   series in the result object.
      # @return [Multi] A multi-series collection of results
      #
      # @see https://oss.redislabs.com/redistimeseries/commands/#tsmrangetsmrevrange
      def mrange(range, filter:, count: nil, aggregation: nil, with_labels: false)
        multi_cmd('TS.MRANGE', range, filter, count, aggregation, with_labels)
      end

      # Query across multiple series, returning values from newest to oldest.
      #
      # @param range [Range] A time range over which to query. Beginless and endless ranges
      #   indicate oldest and most recent timestamp, respectively.
      # @param filter [Hash, String] a set of filters to query with. Refer to the {Filters}
      #   documentation for more details on how to filter.
      # @param count [Integer] The maximum number of results to return for each series.
      # @param aggregation [Array(<String, Symbol>, Integer), Aggregation]
      #   The aggregation to apply. Can be an {Aggregation} object, or an array of
      #   aggregation_type and duration +[:avg, 120000]+
      # @param with_labels [Boolean] Whether to return the label details of the matched
      #   series in the result object.
      # @return [Multi] A multi-series collection of results
      #
      # @see https://oss.redislabs.com/redistimeseries/commands/#tsmrangetsmrevrange
      def mrevrange(range, filter:, count: nil, aggregation: nil, with_labels: false)
        multi_cmd('TS.MREVRANGE', range, filter, count, aggregation, with_labels)
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

      def multi_cmd(cmd_name, range, filter, count, agg, with_labels)
        filters = Filters.new(filter)
        filters.validate!
        cmd(
          cmd_name,
          (range.begin || '-'),
          (range.end || '+'),
          (['COUNT', count] if count),
          Aggregation.parse(agg)&.to_a,
          ('WITHLABELS' if with_labels),
          ['FILTER', filters.to_a]
        ).then { |response| Multi.new(response) }
      end

      def key_for(series_or_string)
        series_or_string.is_a?(self) ? series_or_string.key : series_or_string.to_s
      end

      def parse_madd_values(key, raw)
        if raw.is_a? Hash
          # multiple timestamp => value pairs
          raw.map do |timestamp, value|
            [key, timestamp, value]
          end
        elsif raw.is_a? Array
          # multiple values, no timestamps
          now = Time.now.ts_msec
          raw.each_with_index.map do |value, index|
            [key, now + index, value]
          end
        else
          # single value, no timestamp
          [key, '*', raw]
        end
      end
    end

    # @return [String] the Redis key this time series is stored in
    attr_reader :key

    # @param key [String] the Redis key to store the time series in
    # @param redis [Redis] an optional Redis client
    def initialize(key, redis: self.class.redis)
      @key = key
      @redis = redis
    end

    # Add a value to the series.
    #
    # @param value [Numeric] the value to add
    # @param timestamp [Time, Numeric] the +Time+, or integer timestamp in milliseconds, to add the value
    # @param uncompressed [Boolean] if true, stores data in an uncompressed format
    # @param on_duplicate [String, Symbol] a duplication policy for conflict resolution
    # @param chunk_size [Integer] set default chunk size, in bytes, for the time series
    #
    # @return [Sample] the value that was added
    # @raise [Redis::CommandError] if the value being added is older than the latest timestamp in the series
    #
    # @see TimeSeries::DuplicatePolicy
    def add(value, timestamp = '*', uncompressed: nil, on_duplicate: nil, chunk_size: nil)
      ts = cmd 'TS.ADD',
               key,
               timestamp,
               value,
               ('UNCOMPRESSED' if uncompressed),
               (['CHUNK_SIZE', chunk_size] if chunk_size),
               (DuplicatePolicy.new(on_duplicate).to_a('ON_DUPLICATE') if on_duplicate)
      Sample.new(ts, value)
    end

    # Issues a TS.CREATE command for the current series.
    # You should use class method {Redis::TimeSeries.create} instead.
    # @api private
    def create(retention: nil, uncompressed: nil, labels: nil, duplicate_policy: nil, chunk_size: nil)
      cmd 'TS.CREATE', key,
          (['RETENTION', retention] if retention),
          ('UNCOMPRESSED' if uncompressed),
          (['CHUNK_SIZE', chunk_size] if chunk_size),
          (DuplicatePolicy.new(duplicate_policy).to_a if duplicate_policy),
          (['LABELS', labels.to_a] if labels&.any?)
      self
    end

    # Create a compaction rule for this series.
    #
    # @param dest [String, TimeSeries] the destination series (or key) to aggregate the data
    # @param aggregation [Array(<String, Symbol>, Integer), Aggregation]
    #   The aggregation to apply. Can be an {Aggregation} object, or an array of
    #   aggregation_type and duration +[:avg, 120000]+
    #
    # @return [String] the string "OK"
    # @raise [Redis::TimeSeries::AggregationError] if the given aggregation params are invalid
    # @raise [Redis::CommandError] if the compaction rule cannot be applied to either series
    #
    # @see TimeSeries.create_rule
    def create_rule(dest:, aggregation:)
      self.class.create_rule(source: self, dest: dest, aggregation: aggregation)
    end

    # Delete an existing compaction rule.
    #
    # @param dest [String, TimeSeries] the destination series (or key) the rule applies to
    #
    # @return [String] the string "OK"
    # @raise [Redis::CommandError] if the compaction rule does not exist
    #
    # @see TimeSeries.delete_rule
    def delete_rule(dest:)
      self.class.delete_rule(source: self, dest: dest)
    end

    # Decrement the current value of the series.
    #
    # @param value [Integer] the amount to decrement by
    # @param timestamp [Time, Integer] the Time or integer millisecond timestamp to save the new value at
    # @param uncompressed [Boolean] if true, stores data in an uncompressed format
    # @param chunk_size [Integer] set default chunk size, in bytes, for the time series
    #
    # @return [Integer] the timestamp the value was stored at
    # @see https://oss.redislabs.com/redistimeseries/commands/#tsincrbytsdecrby
    def decrby(value = 1, timestamp = nil, uncompressed: nil, chunk_size: nil)
      cmd 'TS.DECRBY',
          key,
          value,
          (timestamp if timestamp),
          ('UNCOMPRESSED' if uncompressed),
          (['CHUNK_SIZE', chunk_size] if chunk_size)
    end
    alias decrement decrby


    # Delete all data and remove this time series from Redis.
    #
    # @return [1] if the series existed
    # @return [0] if the series did not exist
    def destroy
      redis.del key
    end

    # Get the most recent sample for this series.
    #
    # @return [Sample] the most recent sample for this series
    # @return [nil] if there are no samples in the series
    #
    # @see https://oss.redislabs.com/redistimeseries/commands/#tsget
    def get
      cmd('TS.GET', key).then do |timestamp, value|
        return unless value
        Sample.new(timestamp, value)
      end
    end

    # Increment the current value of the series.
    #
    # @param value [Integer] the amount to increment by
    # @param timestamp [Time, Integer] the Time or integer millisecond timestamp to save the new value at
    # @param uncompressed [Boolean] if true, stores data in an uncompressed format
    # @param chunk_size [Integer] set default chunk size, in bytes, for the time series
    #
    # @return [Integer] the timestamp the value was stored at
    # @see https://oss.redislabs.com/redistimeseries/commands/#tsincrbytsdecrby
    def incrby(value = 1, timestamp = nil, uncompressed: nil, chunk_size: nil)
      cmd 'TS.INCRBY',
          key,
          value,
          (timestamp if timestamp),
          ('UNCOMPRESSED' if uncompressed),
          (['CHUNK_SIZE', chunk_size] if chunk_size)
    end
    alias increment incrby

    # Get information about the series.
    # Note that all properties of {Info} are also available on the series itself
    # via delegation.
    #
    # @return [Info] an info object about the current series
    #
    # @see Info
    # @see https://oss.redislabs.com/redistimeseries/commands/#tsinfo
    def info
      Info.parse series: self, data: cmd('TS.INFO', key)
    end
    def_delegators :info, *Info.members - [:series] + %i[count length size source]

    # Assign labels to the series using +TS.ALTER+
    #
    # @param val [Hash] a hash of label-value pairs
    # @return [Hash] the assigned labels
    #
    # @see https://oss.redislabs.com/redistimeseries/commands/#tsalter
    def labels=(val)
      cmd 'TS.ALTER', key, 'LABELS', val.to_a
    end

    # Add multiple values to the series.
    #
    # @example Adding multiple values with timestamps
    #   ts.madd(2.minutes.ago => 987, 1.minute.ago => 654, Time.current => 321)
    #
    # @param data [Hash] A hash of key-value pairs, with the key being a Time
    #   object or integer timestamp, and the value being a single scalar value
    # @return [Array<Sample, Redis::CommandError>] an array of the resulting samples
    #   added, or a CommandError if the sample in question could not be added to the
    #   series
    #
    def madd(data)
      args = self.class.send(:parse_madd_values, key, data)
      cmd('TS.MADD', args).each_with_index.map do |result, idx|
        result.is_a?(Redis::CommandError) ? result : Sample.new(result, args[idx][2])
      end
    end
    alias multi_add madd
    alias add_multiple madd

    # Get a range of values from the series, from earliest to most recent
    #
    # @param range [Range] A time range over which to query. Beginless and endless ranges
    #   indicate oldest and most recent timestamp, respectively.
    # @param count [Integer] the maximum number of results to return
    # @param aggregation [Array(<String, Symbol>, Integer), Aggregation]
    #   The aggregation to apply. Can be an {Aggregation} object, or an array of
    #   aggregation_type and duration +[:avg, 120000]+
    #
    # @return [Array<Sample>] an array of samples matching the range query
    #
    # @see https://oss.redislabs.com/redistimeseries/commands/#tsrangetsrevrange
    def range(range, count: nil, aggregation: nil)
      range_cmd('TS.RANGE', range, count, aggregation)
    end

    # Get a range of values from the series, from most recent to earliest
    #
    # @param range [Range] A time range over which to query. Beginless and endless ranges
    #   indicate oldest and most recent timestamp, respectively.
    # @param count [Integer] the maximum number of results to return
    # @param aggregation [Array(<String, Symbol>, Integer), Aggregation]
    #   The aggregation to apply. Can be an {Aggregation} object, or an array of
    #   aggregation_type and duration +[:avg, 120000]+
    #
    # @return [Array<Sample>] an array of samples matching the range query
    #
    # @see https://oss.redislabs.com/redistimeseries/commands/#tsrangetsrevrange
    def revrange(range, count: nil, aggregation: nil)
      range_cmd('TS.REVRANGE', range, count, aggregation)
    end

    # Set data retention time for the series using +TS.ALTER+
    #
    # @param val [Integer] the number of milliseconds data should be retained. +0+ means retain forever.
    # @return [Integer] the retention value of the series
    #
    # @see https://oss.redislabs.com/redistimeseries/commands/#tsalter
    def retention=(val)
      # TODO: this should also accept an ActiveSupport::Duration
      cmd 'TS.ALTER', key, 'RETENTION', val.to_i
    end

    # Compare series based on Redis key and configured client.
    # @return [Boolean] whether the two TimeSeries objects refer to the same series
    def ==(other)
      return false unless other.is_a?(self.class)
      key == other.key && redis == other.redis
    end

    private

    def range_cmd(cmd_name, range, count, agg)
      cmd(cmd_name,
          key,
          (range.begin || '-'),
          (range.end || '+'),
          (['COUNT', count] if count),
          Aggregation.parse(agg)&.to_a
         ).map { |ts, val| Sample.new(ts, val) }
    end
  end
end
