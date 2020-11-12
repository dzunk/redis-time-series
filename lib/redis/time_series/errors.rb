class Redis
  class TimeSeries
    # Base error class for convenient +rescue+-ing.
    #
    # Descendant of +Redis::BaseError+, so you can rescue that and capture all
    # time-series errors, as well as standard Redis command errors.
    class Error < Redis::BaseError; end

    # +FilterError+ is raised when a given set of filters is invalid (i.e. does not contain
    # a equality comparison "foo=bar"), or the filter value is unparseable.
    # @see Redis::TimeSeries::Filters
    class FilterError < Error; end

    # +AggregationError+ is raised when attempting to create an aggreation with
    # an unknown type, or when calling a command with an invalid aggregation value.
    # @see Redis::TimeSeries::Aggregation
    class AggregationError < Error; end

    # +UnknownPolicyError+ is raised when attempting to apply an unkown type of
    # duplicate policy when creating or adding to a series.
    # @see Redis::TimeSeries::DuplicatePolicy
    class UnknownPolicyError < Error; end
  end
end
