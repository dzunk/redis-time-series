# frozen_string_literal: true
class Redis
  class TimeSeries
    class Filters
      Equal = Struct.new(:label, :value) do
        self::REGEX = /^[^!]+=[^(]+/

        def self.parse(str)
          new(*str.split('='))
        end

        def to_h
          { label => value }
        end

        def to_s
          "#{label}=#{value}"
        end
      end

      NotEqual = Struct.new(:label, :value) do
        self::REGEX = /^.+!=[^(]+/

        def self.parse(str)
          new(*str.split('!='))
        end

        def to_h
          { label => { not: value } }
        end

        def to_s
          "#{label}!=#{value}"
        end
      end

      Absent = Struct.new(:label) do
        self::REGEX = /^[^!]+=$/

        def self.parse(str)
          new(str.delete('='))
        end

        def to_h
          { label => false }
        end

        def to_s
          "#{label}="
        end
      end

      Present = Struct.new(:label) do
        self::REGEX = /^.+!=$/

        def self.parse(str)
          new(str.delete('!='))
        end

        def to_h
          { label => true }
        end

        def to_s
          "#{label}!="
        end
      end

      AnyValue = Struct.new(:label, :values) do
        self::REGEX = /^[^!]+=\(.+\)/

        def self.parse(str)
          label, values = str.split('=')
          values = values.tr('()', '').split(',')
          new(label, values)
        end

        def to_h
          { label => values }
        end

        def to_s
          "#{label}=(#{values.map(&:to_s).join(',')})"
        end
      end

      NoValues = Struct.new(:label, :values) do
        self::REGEX = /^.+!=\(.+\)/

        def self.parse(str)
          label, values = str.split('!=')
          values = values.tr('()', '').split(',')
          new(label, values)
        end

        def to_h
          { label => { not: values } }
        end

        def to_s
          "#{label}!=(#{values.map(&:to_s).join(',')})"
        end
      end

      TYPES = [Equal, NotEqual, Absent, Present, AnyValue, NoValues]
      TYPES.each do |type|
        define_method "#{type.to_s.split('::').last.gsub(/(.)([A-Z])/,'\1_\2').downcase}" do
          filters.select { |f| f.is_a? type }
        end
      end

      attr_reader :filters

      def initialize(filters = nil)
        @filters = case filters
                   when String then parse_string(filters)
                   when Hash then parse_hash(filters)
                   else []
                   end
      end

      def validate!
        valid? || raise(InvalidFilters, 'Filtering requires at least one equality comparison')
      end

      def valid?
        !!filters.find { |f| f.is_a? Equal }
      end

      def to_a
        filters.map(&:to_s)
      end

      def to_h
        filters.reduce({}) { |h, filter| h.merge(filter.to_h) }
      end

      def to_s
        to_a.join(' ')
      end

      private

      def parse_string(filter_string)
        return unless filter_string.is_a? String
        filter_string.split(' ').map do |str|
          match = TYPES.find { |f| f::REGEX.match? str }
          raise(InvalidFilters, "Unable to parse '#{str}'") unless match
          match.parse(str)
        end
      end

      def parse_hash(filter_hash)
        return unless filter_hash.is_a? Hash
        filter_hash.map do |label, value|
          case value
          when TrueClass then Present.new(label)
          when FalseClass then Absent.new(label)
          when Array then AnyValue.new(label, value)
          when Hash
            raise(InvalidFilters, "Invalid filter hash value #{value}") unless value.keys === [:not]
            (v = value.values.first).is_a?(Array) ? NoValues.new(label, v) : NotEqual.new(label, v)
          else Equal.new(label, value)
          end
        end
      end
    end
  end
end
