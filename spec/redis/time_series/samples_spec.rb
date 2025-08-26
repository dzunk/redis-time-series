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
    let(:timestamp4) { Time.parse("2024-03-12 12:00:00").to_i * 1000 }
    let(:samples1) { described_class.new([Redis::TimeSeries::Sample.new(timestamp1, 1), Redis::TimeSeries::Sample.new(timestamp2, 2)]) }
    let(:samples2) { described_class.new([Redis::TimeSeries::Sample.new(timestamp1, 3), Redis::TimeSeries::Sample.new(timestamp3, 4), Redis::TimeSeries::Sample.new(timestamp4, 5)]) }
    let(:merged_samples) { described_class.merge(sample_sets: [samples1, samples2]) }

    describe ".merge" do
      context "with default merge_strategy: :keep_all" do
        it "merges multiple arrays of samples to one array" do
          result = described_class.merge(sample_sets: [samples1, samples2])
          expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2, timestamp3, timestamp4])
          expect(result.map { |s| s.value }).to eq([[1, 3], [2], [4], [5]])
        end
      end

      context "with merge_strategy: :keep_equal" do
        it "merges multiple arrays of samples to one array" do
          result = described_class.merge(sample_sets: [samples1, samples2], merge_strategy: :keep_equal)
          expect(result.map { |s| s.ts_msec }).to eq([timestamp1])
          expect(result.map { |s| s.value }).to eq([[1, 3]])
        end
      end

      context "with default merge_strategy: :keep_first" do
        it "merges multiple arrays of samples to one array" do
          result = described_class.merge(sample_sets: [samples1, samples2], merge_strategy: :keep_first)

          expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2])
          expect(result.map { |s| s.value }).to eq([[1, 3], [2]])
        end
      end
    end

    describe "#multiply_values!" do
      it "multiplies an array of values in a Samples object containing CalculatedSample objects" do
        result = samples1.multiply_values!(factor: 2)
        expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2])
        expect(result.map { |s| s.value }).to eq([2, 4])
      end
    end

    describe "#divide_values!" do
      it "divides of values in a Samples object containing CalculatedSample objects" do
        result = samples1.divide_values!(factor: 2)
        expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2])
        expect(result.map { |s| s.value }).to eq([0.5, 1])
      end
    end

    describe "#filter_negative_values!" do
      it "divides of values in a Samples object containing CalculatedSample objects" do
        samples = described_class.new([Redis::TimeSeries::Sample.new(timestamp1, -1), Redis::TimeSeries::Sample.new(timestamp2, 2)])
        result = samples.filter_negative_values!
        expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2])
        expect(result.map { |s| s.value }).to eq([0, 2])
      end
    end

    describe "#set_negative_values!" do
      it "divides of values in a Samples object containing CalculatedSample objects" do
        result = samples1.set_negative_values!
        expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2])
        expect(result.map { |s| s.value }).to eq([-1, -2])
      end
    end

    describe "#round_values!" do
      it "rounds of values in a Samples object containing CalculatedSample objects" do
        samples = described_class.new([Redis::TimeSeries::Sample.new(timestamp1, 1), Redis::TimeSeries::Sample.new(timestamp2, "2.21235")])
        result = samples.round_values!(2)
        expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2])
        expect(result.map { |s| s.value }).to eq([1, 2.21])
      end
    end

    describe "methods that work on merged samples" do
      describe "#sum_values!" do
        it "sums an array of values in a Samples object containing CalculatedSample objects" do
          result = merged_samples.sum_values!
          expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2, timestamp3, timestamp4])
          expect(result.map { |s| s.value }).to eq([4, 2, 4, 5])
        end
      end

      describe "#avg_values!" do
        it "returns the average of an array of values in a Samples object containing CalculatedSample objects" do
          result = merged_samples.avg_values!
          expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2, timestamp3, timestamp4])
          expect(result.map { |s| s.value }).to eq([2, 2, 4, 5])
        end
      end

      describe "#subtract_values!" do
        it "merges multiple arrays of samples to one array" do
          result = merged_samples.subtract_values!
          expect(result.map { |s| s.ts_msec }).to eq([timestamp1, timestamp2, timestamp3, timestamp4])
          expect(result.map { |s| s.value }).to eq([-2, 2, 4, 5])
        end
      end

      context "when the sample values do not contain an array" do
        it "raises a CalculationError" do
          expect { samples1.sum_values! }.to raise_error(Redis::TimeSeries::CalculationError)
          expect { samples1.avg_values! }.to raise_error(Redis::TimeSeries::CalculationError)
          expect { samples1.subtract_values! }.to raise_error(Redis::TimeSeries::CalculationError)
        end
      end
    end
  end
end
