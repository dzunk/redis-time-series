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
        return agg if agg.is_a?(self)
        return new(agg.first, agg.last) if agg.is_a?(Array) && agg.size == 2
        raise InvalidAggregation, "Couldn't parse #{agg} into an aggregation rule!"
      end

      def initialize(type, duration)
        unless TYPES.include? type.to_s
          raise InvalidAggregation, "#{type} is not a valid aggregation type!"
        end
        @type = type.to_s
        @duration = duration.to_i
      end

      def to_a
        ['AGGREGATION', type, duration]
      end

      def to_s
        to_a.join(' ')
      end
    end
  end
end
