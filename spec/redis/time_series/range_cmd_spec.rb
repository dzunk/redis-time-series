# frozen_string_literal: true

require "spec_helper"

RSpec.describe Redis::TimeSeries::RangeCmd do
  subject(:range) { described_class.new(timeseries: ts) }

  subject(:ts) { "mock_ts" }

  let(:key) { "range_test" }

  describe ".new" do
    it "returns an instance of RangeCmd" do
      expect(range).to be_a(described_class)
    end
  end

  describe "#options" do
    it "returns an array of options that are set" do
      expect(range.options).to be_an(Array)
    end
  end

  describe "#cmd" do
    it "calls cmd on the timeseries" do
      expect(range).to receive(:cmd)
      range.cmd
    end
  end

  describe "#revrange" do
    it "sets the command to TS.REVRANGE" do
      r = range
      r.revrange
      expect(r.command).to eq("TS.REVRANGE")
    end
  end
end
