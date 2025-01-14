# frozen_string_literal: true
class Redis
  class TimeSeries
    # A sample is an immutable value object that represents a single data point within a time series.
    class Sample

      # @return [Time] the sample's timestamp
      attr_reader :time,:ts_msec
      # @return [BigDecimal] the decimal value of the sample
      attr_accessor :value

      # Samples are returned by time series query methods, there's no need to create one yourself.
      # @api private
      # @see TimeSeries#get
      # @see TimeSeries#range
      def initialize(timestamp, value)
        @ts_msec = timestamp
        @time = Time.at(timestamp / 1000)
        @value = BigDecimal(value)
      end

      # @return [Hash] a hash representation of the sample
      # @example
      #   {:timestamp=>1595199272401, :value=>0.2e1}
      def to_h
        {
          timestamp: ts_msec,
          value: value
        }
      end
    end
  end
end
