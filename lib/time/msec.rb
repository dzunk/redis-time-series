# frozen_string_literal: true
class Time
  # TODO: use refinemenets instead of monkey-patching Time
  def ts_msec
    (to_f * 1000.0).to_i
  end
end
