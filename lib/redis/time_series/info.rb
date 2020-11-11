# frozen_string_literal: true
class Redis
  class TimeSeries
    # The Info struct wraps the result of the +TS.INFO+ command with method access.
    # It also applies some limited parsing to the result values, mainly snakifying
    # the property keys, and instantiating Rule objects if necessary.
    #
    # All properties of the struct are also available on a TimeSeries object itself
    # via delegation.
    #
    # @!attribute [r] chunk_count
    #   @return [Integer] number of memory chunks used for the time-series
    # @!attribute [r] chunk_size
    #   @return [Integer] amount of allocated memory in bytes
    # @!attribute [r] chunk_type
    #   @return [String] whether the chunk is "compressed" or "uncompressed"
    # @!attribute [r] first_timestamp
    #   @return [Integer] first timestamp present in the time-series (milliseconds since epoch)
    # @!attribute [r] labels
    #   @return [Hash] a hash of label-value pairs that represent metadata labels of the time-series
    # @!attribute [r] last_timestamp
    #   @return [Integer] last timestamp present in the time-series (milliseconds since epoch)
    # @!attribute [r] max_samples_per_chunk
    #   @return [Integer] maximum number of samples per memory chunk
    # @!attribute [r] memory_usage
    #   @return [Integer] total number of bytes allocated for the time-series
    # @!attribute [r] retention_time
    #   @return [Integer] retention time, in milliseconds, for the time-series.
    #     A zero value means unlimited retention.
    # @!attribute [r] rules
    #   @return [Array<Rule>] an array of configured compaction {Rule}s
    # @!attribute [r] series
    #   @return [TimeSeries] the series this info is from
    # @!attribute [r] source_key
    #   @return [String, nil] the key of the source series, if this series is the destination
    #     of a compaction rule
    # @!attribute [r] total_samples
    #   @return [Integer] the total number of samples in the series
    #
    # @see TimeSeries#info
    # @see https://oss.redislabs.com/redistimeseries/commands/#tsinfo
    Info = Struct.new(
      :chunk_count,
      :chunk_size,
      :chunk_type,
      :duplicate_policy,
      :first_timestamp,
      :labels,
      :last_timestamp,
      :max_samples_per_chunk,
      :memory_usage,
      :retention_time,
      :rules,
      :series,
      :source_key,
      :total_samples,
      keyword_init: true
    ) do
      class << self
        # @api private
        # @return [Info]
        def parse(series:, data:)
          build_hash(data)
            .then { |h| transform_hash_values(h, series) }
            .then { |h| new(h) }
        end

        private

        def build_hash(data)
          data.each_slice(2).reduce({}) do |h, (key, value)|
            # Convert camelCase info keys to snake_case
            key = key.gsub(/(.)([A-Z])/,'\1_\2').downcase.to_sym
            # Skip unknown properties
            next h unless members.include?(key)
            h.merge(key => value)
          end
        end

        def transform_hash_values(hash, series)
          hash[:series] = series
          hash[:labels] = hash[:labels].to_h.transform_values { |v| v.to_i.to_s == v ? v.to_i : v }
          hash[:rules] = hash[:rules].map { |d| Rule.new(source: series, data: d) }
          hash
        end
      end

      alias count total_samples
      alias length total_samples
      alias size total_samples

      # If this series is the destination of a compaction rule, returns the source series of the data.
      # @return [TimeSeries, nil] the series referred to by {source_key}
      def source
        return unless source_key
        @source ||= TimeSeries.new(source_key, redis: series.redis)
      end
    end
  end
end
