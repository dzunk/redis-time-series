# frozen_string_literal: true
class Redis
  class TimeSeries
    Info = Struct.new(
      :series,
      :total_samples,
      :memory_usage,
      :first_timestamp,
      :last_timestamp,
      :retention_time,
      :chunk_count,
      :max_samples_per_chunk,
      :labels,
      :source_key,
      :rules,
      keyword_init: true
    ) do
      def self.parse(raw_array, series:)
        raw_array.each_slice(2).reduce({}) do |h, (key, value)|
          # Convert camelCase info keys to snake_case
          h[key.gsub(/(.)([A-Z])/,'\1_\2').downcase] = value
          h
        end.then do |parsed_hash|
          parsed_hash['series'] = series
          parsed_hash['labels'] = parsed_hash['labels'].to_h
          parsed_hash['rules'] = parsed_hash['rules'].map { |r| Rule.new(r, source: series) }
          new(parsed_hash)
        end
      end
    end
  end
end
