class Redis
  class TimeSeries
    # Base error class for convenient `rescue`ing
    class Error < StandardError; end

    # Invalid filter error is raised when attempting to filter without at least
    # one equality comparison ("foo=bar")
    class FilterError < Error; end

    # Aggregation error is raised when attempting to create anaggreation with
    # an unknown type, or when calling a command with an invalid aggregation value.
    # @see Redis::TimeSeries::Aggregation
    class AggregationError < Error; end
  end
end
