# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Redis::TimeSeries::Aggregation do
  subject(:agg) { described_class.new(type, duration) }

  let(:type) { :avg }
  let(:duration) { 60000 }

  describe '.parse' do
    subject(:agg) { described_class.parse(raw) }

    context 'given an Aggregation' do
      let(:raw) { described_class.new :avg, 12345 }

      it { is_expected.to be raw }
    end

    context 'given a two-element Array' do
      let(:raw) { [:min, 1234] }

      it { is_expected.to eq described_class.new(:min, 1234) }
    end

    context 'given nil' do
      let(:raw) { nil }

      it { is_expected.to be_nil }
    end

    context 'anything else' do
      let(:raw) { 'foo' }

      specify { expect { agg }.to raise_error Redis::TimeSeries::AggregationError }
    end
  end

  describe '#initialize' do
    it 'requires a type and duration' do
      expect { described_class.new }.to raise_error ArgumentError
      expect { described_class.new(:avg) }.to raise_error ArgumentError
      expect { described_class.new(:avg, 123) }.not_to raise_error
    end

    context 'given an invalid type' do
      specify { expect { described_class.new('foo', 123) }.to raise_error Redis::TimeSeries::AggregationError }
    end

    context 'given an ActiveSupport::Duration' do
      it 'converts it to milliseconds' do
        expect(described_class.new(:avg, 15.minutes).duration).to eq 900000
      end
    end
  end

  describe '#type' do
    it 'returns the type as a string' do
      expect(agg.type).to eq type.to_s
    end
  end

  describe '#aggregation_type' do
    it 'is an alias for #type' do
      expect(agg.aggregation_type).to eq agg.type
    end
  end

  describe '#duration' do
    it 'returns the duration' do
      expect(agg.duration).to eq duration
    end
  end

  describe '#time_bucket' do
    it 'is an alias for #duration' do
      expect(agg.time_bucket).to eq agg.duration
    end
  end

  describe '.to_a' do
    it 'returns a command array' do
      expect(agg.to_a).to eq ['AGGREGATION', type.to_s, duration]
    end
  end

  describe '.to_s' do
    it 'returns a command string' do
      expect(agg.to_s).to eq "AGGREGATION #{type} #{duration}"
    end
  end

  describe '==' do
    let(:other) { described_class.new(:max, 12345) }

    context 'when type and duration are equal' do
      let(:type) { other.type }
      let(:duration) { other.duration }

      it { is_expected.to eq other }
    end

    context 'when type and duration are not equal' do
      it { is_expected.not_to eq other }
    end
  end
end
