# frozen_string_literal: true
class Redis
  class TimeSeries
    # A {Multi} is a collection of multiple series and their samples, returned
    # from a multi command (e.g. TS.MGET or TS.MRANGE).
    #
    # @see TimeSeries.mrange
    # @see TimeSeries.mrevrange
    class Multi < DelegateClass(Array)
      # Multis are initialized by one of the class-level query commands.
      # There's no need to ever create one yourself.
      # @api private
      def initialize(result_array)
        super(result_array.map do |res|
          Result.new(
            TimeSeries.new(res[0]),
            res[1],
            res[2].map { |s| Sample.new(s[0], s[1]) }
          )
        end)
      end

      # Access a specific result by either array position, or hash lookup.
      #
      # @param index_or_key [Integer, String] The integer position, or series
      #   key, of the specific result to return.
      # @return [Multi::Result, nil] A single series result, or nil if there is
      #   no matching series.
      def [](index_or_key)
        return super if index_or_key.is_a?(Integer)
        find { |result| result.series.key == index_or_key.to_s }
      end

      # Get all the series keys that are present in this result collection.
      # @return [Array<String>] An array of the series keys in these results.
      def keys
        map { |r| r.series.key }
      end

      # Get all the series objects that are present in this result collection.
      # @return [Array<TimeSeries>] An array of the series in these results.
      def series
        map(&:series)
      end

      # Convert these results into a hash, keyed by series name.
      # @return [Hash<Array>] A hash of series names and samples.
      # @example
      #   {"ts3"=>
      #     [{:timestamp=>1623945216042, :value=>0.1e1},
      #      {:timestamp=>1623945216055, :value=>0.3e1},
      #      {:timestamp=>1623945216069, :value=>0.2e1}]}
      def to_h
        super do |result|
          [result.series.key, result.samples.map(&:to_h)]
        end
      end

      # Get a count of all matching samples from all series in this result collection.
      # @return [Integer] The total size of all samples from all series in these results.
      def sample_count
        reduce(0) { |size, r| size += r.samples.size }
      end

      Result = Struct.new(:series, :labels, :samples) do
        def values
          samples.map(&:value)
        end
      end
    end
  end
end
