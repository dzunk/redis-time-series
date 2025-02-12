# frozen_string_literal: true

RSpec.describe Redis::TimeSeries::Samples do
  subject(:samples) { described_class.new([sample]) }

  let(:sample) { Redis::TimeSeries::Sample.new(timestamp, value) }

  let(:timestamp) { 1591590303100 }
  let(:value) { '1.23' }

  describe '#to_a' do
    subject { samples.to_a }

    it { is_expected.to be_a Array }

    context "with raw_timestamps: false" do
      it { is_expected.to eq [[sample.time, sample.value]] }
    end

    context "with raw_timestamps: true" do
      subject { samples.to_a(raw_timestamps: true) }

      it { is_expected.to eq [[sample.ts_msec, sample.value]] }
    end
  end

  describe '#to_h' do
    subject { samples.to_h }

    it { is_expected.to be_a Hash }

    context "with raw_timestamps: false" do
      it { is_expected.to eq({ sample.time => sample.value }) }
    end

    context "with raw_timestamps: true" do
      subject { samples.to_h(raw_timestamps: false) }

      it { is_expected.to eq({ sample.time => sample.value }) }
    end
  end

  describe "calculations" do
    let(:timestamp1) { Time.parse("2024-03-12 08:29:00").to_i * 1000 }
    let(:timestamp2) { Time.parse("2024-03-12 10:00:00").to_i * 1000 }
    let(:timestamp3) { Time.parse("2024-03-12 11:00:00").to_i * 1000 }
    let(:samples1) { [Redis::TimeSeries::Sample.new(timestamp1, 1), Redis::TimeSeries::Sample.new(timestamp2, 2)] }
    let(:samples2) { [Redis::TimeSeries::Sample.new(timestamp1, 3), Redis::TimeSeries::Sample.new(timestamp3, 4)] }
    let(:merged_samples) { described_class.merge(sample_sets: [samples1, samples2]) }

    describe ".merge" do
      it "merges multiple arrays of samples to one array" do
        result = described_class.merge(sample_sets: [samples1, samples2])
        expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2, timestamp3])
        expect(result.map { |s| s.value }).to eq([[1, 3], [2], [4]])
      end
    end

    describe ".sum_values!" do
      it "merges multiple arrays of samples to one array" do
        result = described_class.sum_values!(calculated_samples: merged_samples)
        expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2, timestamp3])
        expect(result.map { |s| s.value }).to eq([4, 2, 4])
      end
    end

    describe ".multiply_values!" do
      it "merges multiple arrays of samples to one array" do
        result = described_class.multiply_values!(samples: samples1, factor: 2)
        expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2])
        expect(result.map { |s| s.value }).to eq([2, 4])
      end
    end

    describe ".subtract_values!" do
      it "merges multiple arrays of samples to one array" do
        result = described_class.subtract_values!(calculated_samples: merged_samples)
        expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2, timestamp3])
        expect(result.map { |s| s.value }).to eq([-2, 2, 4])
      end
    end
  end
end
