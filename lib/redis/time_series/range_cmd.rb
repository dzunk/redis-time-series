# frozen_string_literal: true

class Redis
  class TimeSeries
    # The +Redis::TimeSeries::RangeCmd+ class is used to chain options for the TS.RANGE command
    class RangeCmd
      attr_reader :command, :timeseries
      attr_accessor :filter_by_ts, :filter_by_range, :filter_by_value, :count, :align, :empty

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
        result = []
        queried_timestamps = []
        @timeseries.redis.with do |conn|
          result = conn.pipelined do |pipeline|
            if @aggregation&.duration == 2629746000
              queried_timestamps = monthly_aggregation(pipeline)
            elsif @aggregation&.duration == 86400000
              daily_aggregation(pipeline)
            else
              if @filter_by_ts
                sliced_cmd_for_filter_by_ts(pipeline)
              elsif @filter_by_range
                sliced_cmd_for_filter_by_range(pipeline)
              else
                @timeseries.range_cmd(self, pipeline: pipeline)
              end
            end
          end
        end

        #flatten rows because they might come from multiple queries
        result.map!{|row| row.flatten!}

        #redis timeseries will return an empty array if there are no results.
        #if @empty is set we want a sample with NaN instead
        if @empty && queried_timestamps.present?
          result.map!{|row|
            timestamp = queried_timestamps.pop
            row.blank? ? [timestamp,BigDecimal("NaN")] : row
          }
        end

        Samples.new(result.filter_map { |timestamp, val| timestamp.nil? ? nil : Sample.new(timestamp, val) })
      end

      private
        def monthly_aggregation(pipeline)
          original_start_time = @start_time
          original_end_time = @end_time
          original_aggregation = @aggregation
          queried_timestamps = []

          Redis::TimeSeries.new(@timeseries.key)
          current_start = Time.at(start_time)
          current_end = Time.at(start_time).end_of_month - 1
          while current_end < original_end_time
            self.aggregation = [@aggregation.type, ((current_end - current_start).round) * 1000]
            @start_time = current_start
            @end_time = current_end
            queried_timestamps << current_start.to_i * 1000

            if @filter_by_range
              sliced_cmd_for_filter_by_range(pipeline)
            else
              @timeseries.range_cmd(self, pipeline: pipeline)
            end

            current_start = Time.at(current_start).advance(months: 1)
            current_end = Time.at(current_start).end_of_month - 1
          end

          @start_time = original_start_time
          @end_time = original_end_time
          @aggregation = original_aggregation
          queried_timestamps.reverse!
        end

        def daily_aggregation(pipeline)
          Redis::TimeSeries.new(@timeseries.key)

          # set up, make sure the while runs at least once
          current_start = Time.at(start_time)
          ts_end_time = Time.at(end_time)
          current_end = end_time - 1

          while current_end < ts_end_time

            day_after_dst_transition = Time.at(TZInfo::Timezone.get(Time.now.zone).period_for_local(current_start).end_transition.timestamp_value + 1.day).beginning_of_day
            current_end = (day_after_dst_transition < ts_end_time ? Time.at(day_after_dst_transition) - 1 : ts_end_time)

            @start_time = current_start
            @end_time = current_end

            if @filter_by_ts
              sliced_cmd_for_filter_by_ts(pipeline)
            elsif @filter_by_range
              sliced_cmd_for_filter_by_range(pipeline)
            else
              @timeseries.range_cmd(self, pipeline: pipeline)
            end

            current_start = day_after_dst_transition
          end
        end

        def sliced_cmd_for_filter_by_range(pipeline)
          result = []
          start_time = @start_time
          end_time = @end_time
          start_end_range = start_time..end_time
          @align = start_time
          filter_by_range.select { |f| start_end_range.cover?(f) }.each do |range|
            @start_time = range.begin
            @end_time = range.end
            result << @timeseries.range_cmd(self, pipeline: pipeline)
          end
          @start_time = start_time
          @end_time = end_time
          result
        end

        def sliced_cmd_for_filter_by_ts(pipeline)
          result = []
          all_filter_by_ts = @filter_by_ts
          all_filter_by_ts.each_slice(128) do |filter_by_ts|
            @filter_by_ts = filter_by_ts
            result << @timeseries.range_cmd(self, pipeline: pipeline)
          end
          @filter_by_ts = all_filter_by_ts
          result
        end
    end
  end
end
