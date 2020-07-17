# frozen_string_literal: true
class Redis
  class TimeSeries
    class Filter
      Equal = Struct.new(:label, :value) do
        self::REGEX = /^[^!]+=[^(]+/

        def self.parse(str)
          new(*str.split('='))
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

        def to_s
          "#{label}!=#{value}"
        end
      end

      Absent = Struct.new(:label) do
        self::REGEX = /^[^!]+=$/

        def self.parse(str)
          new(str.delete('='))
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

        def to_s
          "#{label}=(#{values.join(',')})"
        end
      end

      NoValues = Struct.new(:label, :values) do
        self::REGEX = /^.+!=\(.+\)/

        def self.parse(str)
          label, values = str.split('!=')
          values = values.tr('()', '').split(',')
          new(label, values)
        end

        def to_s
          "#{label}!=(#{values.join(',')})"
        end
      end

      TYPES = [Equal, NotEqual, Absent, Present, AnyValue, NoValues]
      TYPES.each do |type|
        define_method "#{type.to_s.split('::').last.gsub(/(.)([A-Z])/,'\1_\2').downcase}_filters" do
          filters.select { |f| f.is_a? type }
        end
      end

      attr_reader :filters

      def initialize(filters = nil)
        filters = parse_string(filters) if filters.is_a?(String)
        @filters = filters.presence || {}
      end

      def validate!
        valid? || raise('Filtering requires at least one equality comparison')
      end

      def valid?
        !!filters.find { |f| f.is_a? Equal }
      end

      def to_a
        filters.map(&:to_s)
      end

      private

      def parse_string(filter_string)
        filter_string.split(' ').map do |str|
          match = TYPES.find { |f| f::REGEX.match? str }
          raise "Unable to parse '#{str}'" unless match
          match.parse(str)
        end
      end
    end
  end
end
