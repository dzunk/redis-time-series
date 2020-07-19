# frozen_string_literal: true
class Redis
  class TimeSeries
    class Rule
      attr_reader :source, :destination_key, :aggregation

      def initialize(source:, data:)
        @source = source
        @destination_key, duration, aggregation_type = data
        @aggregation = Aggregation.new(aggregation_type, duration)
      end

      def destination
        @dest ||= TimeSeries.new(destination_key, redis: source.redis)
      end
      alias dest destination

      def delete
        source.delete_rule(dest: destination_key)
      end

      def source_key
        source.key
      end
    end
  end
end
