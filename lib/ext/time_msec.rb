# frozen_string_literal: true

# The +TimeMsec+ module is a refinement for the +Time+ class that makes it easier
# to work with millisecond timestamps.
#
# @example
#   Time.now.to_i    # 1595194259
#   Time.now.ts_msec # NoMethodError
#
#   using TimeMsec
#
#   Time.now.to_i    # 1595194259
#   Time.now.ts_msec # 1595194259000
#
#   Time.from_msec(1595194259000) # 2020-07-19 14:30:59 -0700
module TimeMsec
  refine Time do
    # TODO: convert to #to_msec
    def ts_msec
      (to_f * 1000.0).to_i
    end
  end

  refine Time.singleton_class do
    def from_msec(timestamp)
      at(timestamp / 1000.0)
    end
  end
end
