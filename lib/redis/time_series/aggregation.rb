# frozen_string_literal: true
class Redis
  class TimeSeries
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

      attr_reader :type, :duration

      alias aggregation_type type
      alias time_bucket duration

      def self.parse(agg)
        return unless agg
        return agg if agg.is_a?(self)
        return new(agg.first, agg.last) if agg.is_a?(Array) && agg.size == 2
        raise AggregationError, "Couldn't parse #{agg} into an aggregation rule!"
      end

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

      def to_a
        ['AGGREGATION', type, duration]
      end

      def to_s
        to_a.join(' ')
      end

      def ==(other)
        parsed = self.class.parse(other)
        type == parsed.type && duration == parsed.duration
      end
    end
  end
end
