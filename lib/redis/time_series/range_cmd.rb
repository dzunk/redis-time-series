# frozen_string_literal: true

class Redis
  class TimeSeries
    # The +Redis::TimeSeries::RangeCmd+ class is used to chain options for the TS.RANGE command
    class RangeCmd
      attr_reader :command, :timeseries
      attr_accessor :filter_by_ts, :filter_by_value, :count, :align, :empty

      def initialize(timeseries:, start_time: "-", end_time: "+")
        @timeseries = timeseries
        @start_time = start_time || "-"
        @end_time = end_time || "+"
        @command = "TS.RANGE"
        @align = "start"
        @empty = true
        @latest = false
        @aggregation = nil
      end

      def start_time
        Time.at(@start_time.is_a?(Numeric) ? @start_time / 1000 : @start_time)
      end
      def end_time
        Time.at(@end_time.is_a?(Numeric) ? @end_time / 1000 : @end_time)
      end

      def aggregation=(aggregation)
        @aggregation = Aggregation.parse(aggregation)
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
        options << @aggregation.to_a if @aggregation
        options << "empty" if @empty && @aggregation
        options << "latest" if @latest && @aggregation
        options
      end

      def cmd
        if @aggregation&.duration == 2629746000
          monthly_aggregation
        elsif @aggregation&.duration == 86400000
          daily_aggregation
        else
          @timeseries.range_cmd(self)
        end
      end

      private
        def monthly_aggregation
          ts = Redis::TimeSeries.new(@timeseries.key)
          samples = []
          current_start = Time.at(start_time)
          current_end = Time.at(start_time).end_of_month - 1
          while current_end < Time.at(end_time)
            sample_subset = ts.range(current_start..current_end, aggregation: [@aggregation.type, (current_end - current_start).round * 1000])
            # if nothing is found add an empty value so it can be interpolated later
            sample_subset << Redis::TimeSeries::Sample.new(current_start.to_i * 1000, BigDecimal("NaN")) if sample_subset.empty?
            samples << sample_subset

            current_start = Time.at(current_start).advance(months: 1)
            current_end = Time.at(current_start).end_of_month - 1.second
          end
          samples.flatten
        end

        def daily_aggregation
          Redis::TimeSeries.new(@timeseries.key)
          samples = []

          # set up, make sure the while runs at least once
          current_start = Time.at(start_time)
          ts_end_time = Time.at(end_time)
          current_end = end_time - 1

          while current_end < ts_end_time

            day_after_dst_transition = Time.at(TZInfo::Timezone.get(Time.now.zone).period_for_local(current_start).end_transition.timestamp_value + 1.day).beginning_of_day
            current_end = (day_after_dst_transition < ts_end_time ? Time.at(day_after_dst_transition) - 1 : ts_end_time)

            @start_time = current_start
            @end_time = current_end
            sample_subset = @timeseries.range_cmd(self)
            samples << sample_subset

            current_start = day_after_dst_transition
          end

          samples.flatten
        end
    end
  end
end
