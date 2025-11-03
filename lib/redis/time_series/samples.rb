# frozen_string_literal: true

class Redis
  class TimeSeries
    class Samples < DelegateClass(Array)
      attr_accessor :metadata

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

      # supports multiple merge strategies
      # :keep_all merges all records even if the timestamp isn't present in each samples set
      # :keep_equal only merges records if the timestamps are present in all sets
      # :keep_first only merges records if the timestamp is present in the first set
      # :keep_equal or keep_first is recommended if you want to do subtract_values! later.
      def self.merge(sample_sets:, merge_strategy: :keep_all)
        samples_hash = {}
        sample_sets.each_with_index do |samples, index|
          samples.each do |sample|
            sample_default = (merge_strategy.to_sym != :keep_first || (merge_strategy.to_sym == :keep_first && index == 0) ? CalculatedSample.new(sample.ts_msec, []) : nil)
            calculated_sample = samples_hash.fetch(sample.time, sample_default)
            next if calculated_sample.blank?
            calculated_sample.value << sample.value
            samples_hash[sample.time] = calculated_sample
          end
        end
        samples = Samples.new(samples_hash.values)
        samples.select! { |sample| sample.value.count == sample_sets.count } if merge_strategy.to_sym == :keep_equal
        samples.metadata = sample_sets.filter_map { |s| s.metadata }.inject({}) { |result, metadata| metadata.merge(result) }
        samples
      end

      def sum_values!
        self.each do |sample|
          raise(CalculationError, "expected an enumerable in sample.value, but sample is #{sample.inspect}") unless sample.value.is_a?(Enumerable)
          sample.value.map! { |v| v.respond_to?("nan?") && v.nan? ? 0 : v }
          sample.value = sample.value.sum
        end
        self
      end

      def subtract_values!
        self.each do |sample|
          raise(CalculationError, "expected an enumerable in sample.value, but sample is #{sample.inspect}") unless sample.value.is_a?(Enumerable)
          sample.value = sample.value.reduce(sample.value.first * 2) { |result, next_value| result - next_value }
        end
        self
      end

      def avg_values!
        self.each do |sample|
          raise(CalculationError, "expected an enumerable in sample.value, but sample is #{sample.inspect}") unless sample.value.is_a?(Enumerable)
          sample.value = sample.value.sum / sample.value.length
        end
        self
      end

      def min_values!
        self.each do |sample|
          unless sample.value.is_a?(Enumerable)
            raise(CalculationError, "expected an enumerable in sample.value, but sample is #{sample.inspect}")
          end

          cleaned = sample.value.reject { |v| v.respond_to?(:nan?) && v.nan? }
          sample.value = cleaned.min unless cleaned.empty?
        end
        self
      end

      def max_values!
        self.each do |sample|
          unless sample.value.is_a?(Enumerable)
            raise(CalculationError, "expected an enumerable in sample.value, but sample is #{sample.inspect}")
          end

          cleaned = sample.value.reject { |v| v.respond_to?(:nan?) && v.nan? }
          sample.value = cleaned.max unless cleaned.empty?
        end
        self
      end

      def multiply_values!(factor:)
        self.each { |sample| sample.value = sample.value * factor }
        self
      end


      def divide_values!(factor:)
        self.each { |sample| sample.value = sample.value / factor }
        self
      end

      def round_values!(...)
        self.each { |sample| sample.value = sample.value.round(...) }
        self
      end

      def filter_nan!(new_value: 0)
        self.each { |sample| sample.value = new_value if sample.value.respond_to?("nan?") && sample.value.nan? }
        self
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
