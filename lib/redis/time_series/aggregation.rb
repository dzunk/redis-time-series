# frozen_string_literal: true
class Redis
  class TimeSeries
    # An aggregation is a combination of a mathematical function, and a time window over
    # which to apply that function. In RedisTimeSeries, aggregations are used to downsample
    # data from a source series to a destination series, using compaction rules.
    #
    # @see Redis::TimeSeries#create_rule
    # @see Redis::TimeSeries::Rule
    # @see https://oss.redislabs.com/redistimeseries/commands/#aggregation-compaction-downsampling
    class Aggregation
      TYPES = %w[
        avg
        count
        first
        last
        max
        min
        range
        std.p
        std.s
        sum
        var.p
        var.s
      ]

      # @return [String] the type of aggregation to apply
      # @see TYPES
      attr_reader :type
      alias aggregation_type type

      # @return [Integer] the time window to apply the aggregation over, in milliseconds
      attr_reader :duration
      alias time_bucket duration

      # Parse a method argument into an aggregation.
      #
      # @param agg [Array, Aggregation] an aggregation object, or an array of type and duration +[:avg, 60000]+
      # @return [Aggregation] the parsed aggregation, or the original argument if already an aggregation
      # @raise [AggregationError] when given an unparseable value
      def self.parse(agg)
        return unless agg
        return agg if agg.is_a?(self)
        return new(agg.first, agg.last) if agg.is_a?(Array) && agg.size == 2
        raise AggregationError, "Couldn't parse #{agg} into an aggregation rule!"
      end

      # Create a new Aggregation given a type and duration.
      # @param type [String, Symbol] one of the valid aggregation {TYPES}
      # @param duration [Integer, ActiveSupport::Duration]
      #   A time window to apply this aggregation over.
      #   If you're using ActiveSupport, duration objects (e.g. +10.minutes+) will be automatically coerced.
      # @return [Aggregation]
      # @raise [AggregationError] if the given aggregation type is not valid
      def initialize(type, duration)
        type = type.to_s.downcase
        unless TYPES.include? type
          raise AggregationError, "#{type} is not a valid aggregation type!"
        end
        @type = type
        if defined?(ActiveSupport::Duration) && duration.is_a?(ActiveSupport::Duration)
          @duration = duration.in_milliseconds
        else
          @duration = duration.to_i
        end
      end

      # @api private
      # @return [Array]
      def to_a
        ['AGGREGATION', type, duration]
      end

      # @api private
      # @return [String]
      def to_s
        to_a.join(' ')
      end

      # Compares aggregations based on type and duration.
      # @return [Boolean] whether the given aggregations are equivalent
      def ==(other)
        parsed = self.class.parse(other)
        type == parsed.type && duration == parsed.duration
      end
    end
  end
end
