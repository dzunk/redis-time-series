# frozen_string_literal: true

class Redis
  class TimeSeries
    # The +Redis::TimeSeries::RangeCmd+ class is used to chain options for the TS.RANGE command
    class RangeCmd
      attr_reader :command
      attr_accessor :filter_by_ts, :filter_by_value, :count, :align, :empty

      def initialize(timeseries:, start_time: "-", end_time: "+")
        @timeseries = timeseries
        @start_time = start_time || "-"
        @end_time = end_time || "+"
        @command = "TS.RANGE"
        @align = "start"
        @empty = true
        @aggregation = nil
      end

      def aggregation=(aggregation)
        @aggregation = Aggregation.parse(aggregation)&.to_a
        self
      end

      def revrange
        @command = "TS.REVRANGE"
      end

      def options
        options = []
        options << @start_time
        options << @end_time
        options << ["FILTER_BY_TS", @filter_by_ts] if @filter_by_ts
        options << ["FILTER_BY_VALUE", @filter_by_value] if @filter_by_value
        # align can only be used with aggregation
        options << ["ALIGN", @align] if @aggregation
        options << ["COUNT", @count] if @count
        options << @aggregation if @aggregation
        options << "empty" if @empty && @aggregation
        options
      end

      def cmd
        @timeseries.range_cmd(self)
      end
    end
  end
end
