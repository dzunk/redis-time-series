# frozen_string_literal: true
RSpec.describe Redis::TimeSeries::Sample do
  subject(:sample) { described_class.new(timestamp, value) }

  let(:timestamp) { 1591590303100 }
  let(:value) { '1.23' }

  describe '#time' do
    subject { sample.time }

    it { is_expected.to be_a Time }
    it { is_expected.to eq Time.at(timestamp / 1000.0) }
  end

  describe '#value' do
    subject { sample.value }

    it { is_expected.to be_a BigDecimal }
    it { is_expected.to eq BigDecimal(value) }
  end

  describe '#to_msec' do
    subject { sample.to_msec }

    it { is_expected.to be_an Integer }
    it { is_expected.to eq timestamp }
  end

  describe '#to_h' do
    subject { sample.to_h }

    it { is_expected.to be_a Hash }
    it { is_expected.to eq timestamp: timestamp, value: BigDecimal(value) }
  end
end
