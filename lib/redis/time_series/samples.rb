# frozen_string_literal: true

class Redis
  class TimeSeries
    class Samples < DelegateClass(Array)
      def to_a(raw_timestamps: false)
        map do |sample|
          [
            (raw_timestamps ? sample.ts_msec : sample.time),
            sample.value
          ]
        end
      end

      def to_h(raw_timestamps: false)
        to_a(raw_timestamps: raw_timestamps).to_h
      end

      def self.merge(sample_sets:)
        samples_hash = {}
        sample_sets.each do |samples|
          samples.each do |sample|
            calculated_sample = samples_hash.fetch(sample.time, CalculatedSample.new(sample.ts_msec, []))
            calculated_sample.value << sample.value
            samples_hash[sample.time] = calculated_sample
          end
        end
        Samples.new(samples_hash.values)
      end

      def sum_values!
        self.each do |sample|
          raise(CalculationError, "expected an enumerable in sample.value, but sample is #{sample.inspect}") unless sample.value.is_a?(Enumerable)
          sample.value = sample.value.sum
        end
      end

      def subtract_values!
        self.each do |sample|
          raise(CalculationError, "expected an enumerable in sample.value, but sample is #{sample.inspect}") unless sample.value.is_a?(Enumerable)
          sample.value = sample.value.reduce(sample.value.first * 2) { |result, next_value| result - next_value }
        end
      end

      def avg_values!
        self.each do |sample|
          raise(CalculationError, "expected an enumerable in sample.value, but sample is #{sample.inspect}") unless sample.value.is_a?(Enumerable)
          sample.value = sample.value.sum / sample.value.length
        end
      end

      def multiply_values!(factor:)
        self.each { |sample| sample.value = sample.value * factor }
      end


      def divide_values!(factor:)
        self.each { |sample| sample.value = sample.value / factor }
      end

      def round_values!(...)
        self.each { |sample| sample.value = sample.value.round(...) }
      end

      def filter_negative_values!
        self.each { |sample| sample.value = 0 if sample.value.blank? || sample.value <= 0 }
        self
      end

      def set_negative_values!
        self.each { |sample| sample.value = sample.value * -1 }
        self
      end
    end
  end
end
