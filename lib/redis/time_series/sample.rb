# frozen_string_literal: true
class Redis
  class TimeSeries
    class Sample
      TS_FACTOR = 1000.0

      attr_reader :time, :value

      def initialize(timestamp, value)
        @time = Time.at(timestamp / TS_FACTOR)
        @value = BigDecimal(value)
      end

      def ts_msec
        (@time.to_i * TS_FACTOR.to_i) + (@time.usec / TS_FACTOR).round
      end

      def to_h
        {
          timestamp: ts_msec,
          value: value
        }
      end
    end
  end
end
