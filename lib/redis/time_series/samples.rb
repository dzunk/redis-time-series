# frozen_string_literal: true
class Redis
  class TimeSeries
    class Samples < DelegateClass(Array)
      def self.from_madd(values, result)
        new(result.each_with_index.map do |ts, idx|
          ts.is_a?(Redis::CommandError) ? ts : Sample.new(ts, values[idx][2])
        end)
      end

      def self.from_range(raw_values)
        new(raw_values.map { |ts, val| Sample.new(ts, val) })
      end

      def error?
        any? { |sample| sample.is_a?(Redis::CommandError) }
      end

      def to_a(raw_timestamps: false)
        map do |sample|
          [
            (raw_timestamps ? sample.to_msec : sample.time),
            sample.value
          ]
        end
      end

      def to_h(raw_timestamps: false)
        to_a(raw_timestamps: raw_timestamps).to_h
      end
    end
  end
end
