class Redis
  class TimeSeries
    # Base error class for convenient `rescue`ing
    class Error < StandardError; end

    # Invalid filter error is raised when attempting to filter without at least
    # one equality comparison ("foo=bar")
    class InvalidFilters < Error; end

    # Invalid aggregation type error is raised when attempting to create an
    # aggreation with an unknown type.
    # @see Redis::TimeSeries::Aggregation::TYPES
    class InvalidAggregationType < Error; end
  end
end
