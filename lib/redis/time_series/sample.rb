# frozen_string_literal: true
class Redis
  class TimeSeries
    # A sample is an immutable value object that represents a single data point within a time series.
    class Sample
      using TimeMsec

      # @return [Time] the sample's timestamp
      attr_reader :time
      # @return [BigDecimal] the decimal value of the sample
      attr_accessor :value

      # Samples are returned by time series query methods, there's no need to create one yourself.
      # @api private
      # @see TimeSeries#get
      # @see TimeSeries#range
      def initialize(timestamp, value)
        @time = Time.from_msec(timestamp)
        @value = BigDecimal(value)
      end

      # @return [Integer] the millisecond value of the sample's timestamp
      # @note
      #   We're wrapping the method provided by the {TimeMsec} refinement for convenience,
      #   otherwise it wouldn't be callable on {time} and devs would have to litter
      #   +using TimeMsec+ or +* 1000.0+ wherever they wanted the value.
      def to_msec
        time.ts_msec
      end

      # @return [Hash] a hash representation of the sample
      # @example
      #   {:timestamp=>1595199272401, :value=>0.2e1}
      def to_h
        {
          timestamp: to_msec,
          value: value
        }
      end
    end
  end
end
