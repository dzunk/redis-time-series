# frozen_string_literal: true
module TimeMsec
  refine Time do
    def ts_msec
      (to_f * 1000.0).to_i
    end
  end
end
