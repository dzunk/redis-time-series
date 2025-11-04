# frozen_string_literal: true

require "spec_helper"

RSpec.describe Redis::TimeSeries::RangeCmd do
  subject(:range) { described_class.new(timeseries: ts) }

  let(:key) { "time_series_test" }
  subject(:ts) { Redis::TimeSeries.create(key) }

  let(:summer_time) { Time.parse("2024-03-31") }
  let(:winter_time) { Time.parse("2024-10-27") }

  let(:key) { "range_test" }

  after { Redis::TimeSeries.redis.with{ |conn| conn.del(key) } }

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

    context "with an aggregation duration of 1.month" do
      it "returns an array of samples aggregated by the duration of that month" do
        timestamp1 = Time.parse("2024-01-01")
        timestamp2 = Time.parse("2024-02-01")
        timestamp3 = Time.parse("2024-03-01")
        timestamp4 = Time.parse("2024-04-01")

        values = { timestamp1 => 10, timestamp2 => 20, timestamp3 => 30 }
        ts.madd(values)

        range_cmd = described_class.new(timeseries: ts, start_time: timestamp1, end_time: timestamp4)
        range_cmd.aggregation = ["avg", 2629746000]
        result = range_cmd.cmd
        expect(result.map { |sample| sample.value }).to match_array([10, 20, 30])
        expect(result.map { |sample| sample.time }).to eq([timestamp1, timestamp2, timestamp3])
      end

      context "with filter_by_range" do
        it "returns monthly calculated values filtered by range" do
        timestamp1 = Time.parse("2024-01-01")
        timestamp2 = Time.parse("2024-01-02")
        timestamp3 = Time.parse("2024-01-03")
        timestamp4 = Time.parse("2024-01-04")
        timestamp5 = Time.parse("2024-01-05")
        timestamp6 = Time.parse("2024-01-06")
        timestamp7 = Time.parse("2024-02-01")
        timestamp8 = Time.parse("2024-02-29")

          values = { timestamp1 => 10, timestamp2 => 30, timestamp3 => 40, timestamp4 => 45, timestamp5 => 100, timestamp6 => 50, timestamp7 => 50, timestamp8 => 50}
          ts.madd(values)

          range_cmd = described_class.new(timeseries: ts, start_time: timestamp1, end_time: timestamp8.end_of_day)
          range_cmd.aggregation = ["sum", 2629746000]
          range_cmd.filter_by_range = [timestamp2..timestamp3,timestamp5..timestamp6]
          result = range_cmd.cmd#.filter_map { |sample| sample.value.nan? ? nil : sample }
          expect(result.map { |sample| sample.time }).to eq([timestamp1,timestamp8])
          expect(result.map { |sample| sample.value.to_f.round(1) }).to eq([35])
        end
      end

      context "with @empty" do
        it "returns a sample for missing months" do
          timestamp1 = Time.parse("2024-01-01")
          timestamp2 = Time.parse("2024-02-01")
          timestamp3 = Time.parse("2024-03-01")
          timestamp4 = Time.parse("2024-04-01")

          values = { timestamp1 => 10, timestamp3 => 20 }
          ts.madd(values)

          range_cmd = described_class.new(timeseries: ts, start_time: timestamp1, end_time: timestamp4)
          range_cmd.aggregation = ["avg", 2629746000]
          result = range_cmd.cmd
          expect(result.map { |sample| sample.time }).to eq([timestamp1, timestamp2, timestamp3])
        end
      end
    end

    context "with an aggregation duration of 1.day" do
      it "returns daily calculated values considering DST" do
        timestamp1 = (winter_time - 2.days)
        timestamp2 = (winter_time - 1.day)
        timestamp3 = (winter_time)
        timestamp4 = (winter_time + 2.hours)
        timestamp5 = (winter_time + 3.hours)
        timestamp6 = (winter_time + 4.hours)
        timestamp7 = (winter_time + 1.days)
        timestamp8 = (winter_time + 2.days)

        values = { timestamp1 => 10, timestamp2 => 30, timestamp3 => 40, timestamp4 => 45, timestamp5 => 10, timestamp6 => 30, timestamp7 => 40, timestamp8 => 45}
        ts.madd(values)

        range_cmd = described_class.new(timeseries: ts, start_time: timestamp1, end_time: timestamp8)
        range_cmd.aggregation = ["avg", 86400000]
        result = range_cmd.cmd.filter_map { |sample| sample.value.nan? ? nil : sample }
        expect(result.map { |sample| sample.time }).to eq([timestamp1, timestamp2, timestamp3, timestamp4, timestamp5, timestamp6, timestamp7,timestamp8])
        expect(result.map { |sample| sample.value.to_f.round(1) }).to eq([10, 30, 40, 45, 10, 30, 40, 45])
      end

      context "with filter_by_range" do
        it "returns daily calculated values filtered by range" do
        timestamp1 = Time.parse("2024-01-01")
        timestamp2 = Time.parse("2024-01-01") + 1.hour
        timestamp3 = Time.parse("2024-01-01") + 2.hours
        timestamp4 = Time.parse("2024-01-01") + 3.hours

          values = { timestamp1 => 10, timestamp2 => 30, timestamp3 => 40, timestamp4 => 45}
          ts.madd(values)

          range_cmd = described_class.new(timeseries: ts, start_time: timestamp1, end_time: timestamp4)
          range_cmd.aggregation = ["avg", 86400000]
          range_cmd.filter_by_range = [(timestamp2)..(timestamp3)]
          result = range_cmd.cmd#.filter_map { |sample| sample.value.nan? ? nil : sample }
          expect(result.map { |sample| sample.time }).to eq([timestamp1])
          expect(result.map { |sample| sample.value.to_f.round(1) }).to eq([35])
        end
      end
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
