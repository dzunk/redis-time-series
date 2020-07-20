# frozen_string_literal: true
class Redis
  class TimeSeries
    # A compaction rule applies an aggregation from a source series to a destination series.
    # As data is added to the source, it will be aggregated based on any configured rule(s) and
    # distributed to the correct destination(s).
    #
    # Compaction rules are useful to retain data over long time periods without requiring exorbitant
    # amounts of memory and storage. For example, if you're collecting data on a minute-by-minute basis,
    # you may want to retain a week's worth of data at full fidelity, and a year's worth of data downsampled
    # to hourly, which would require 60x less memory.
    class Rule
      # @return [Aggregation] the configured aggregation for this rule
      attr_reader :aggregation

      # @return [String] the Redis key of the destination series
      attr_reader :destination_key

      # @return [TimeSeries] the data source of this compaction rule
      attr_reader :source

      # Manually instantiating a rule does nothing, don't bother.
      # @api private
      # @see Info#rules
      def initialize(source:, data:)
        @source = source
        @destination_key, duration, aggregation_type = data
        @aggregation = Aggregation.new(aggregation_type, duration)
      end

      # Delete this compaction rule.
      # @return [String] the string "OK"
      def delete
        source.delete_rule(dest: destination_key)
      end

      # @return [TimeSeries] the destination time series this rule refers to
      def destination
        @dest ||= TimeSeries.new(destination_key, redis: source.redis)
      end
      alias dest destination

      # @return [String] the Redis key of the source series
      def source_key
        source.key
      end
    end
  end
end
