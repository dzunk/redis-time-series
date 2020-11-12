# frozen_string_literal: true
class Redis
  class TimeSeries
    # Duplication policies can be applied to a time series in order to resolve conflicts
    # when adding data that already exists in the series.
    #
    # @see https://oss.redislabs.com/redistimeseries/master/configuration/#duplicate_policy
    class DuplicatePolicy
      VALID_POLICIES = %i[
        block
        first
        last
        min
        max
        sum
      ].freeze

      attr_reader :policy

      def initialize(policy)
        policy = policy.to_s.downcase.to_sym
        if VALID_POLICIES.include?(policy)
          @policy = policy
        else
          raise UnknownPolicyError, "#{policy} is not a valid duplicate policy"
        end
      end

      def to_a(cmd = 'DUPLICATE_POLICY')
        [cmd, policy]
      end

      def to_s(cmd = 'DUPLICATE_POLICY')
        to_a(cmd).join(' ')
      end

      def ==(other)
        return policy == other.policy if other.is_a?(self.class)
        policy == self.class.new(other).policy
      end

      VALID_POLICIES.each do |policy|
        define_method("#{policy}?") do
          @policy == policy
        end
      end
    end
  end
end
