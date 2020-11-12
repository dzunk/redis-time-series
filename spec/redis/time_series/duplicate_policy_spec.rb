# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Redis::TimeSeries::DuplicatePolicy do
  subject(:policy) { described_class.new(policy_key) }

  let(:policy_key) { :block }

  describe 'valid policies' do
    specify do
      expect(described_class::VALID_POLICIES).to match_array %i[
        block first last min max sum
      ]
    end
  end

  describe '#initialize' do
    context 'when given an unknown policy' do
      let(:policy_key) { :foo }

      it 'raises an error' do
        expect { policy }.to raise_error Redis::TimeSeries::UnknownPolicyError
      end
    end

    it 'accepts symbols' do
      expect { described_class.new(:max) }.not_to raise_error
    end

    it 'accepts strings' do
      expect { described_class.new('max') }.not_to raise_error
    end

    it 'case-insensitively parses' do
      expect(described_class.new('MaX')).to eq described_class.new(:mAx)
    end
  end

  describe '#to_a' do
    it 'returns a command array' do
      expect(policy.to_a).to eq ['DUPLICATE_POLICY', policy_key]
    end

    context 'when overriding the command key' do
      it 'returns the correct array' do
        expect(policy.to_a('ON_DUPLICATE')).to eq ['ON_DUPLICATE', policy_key]
      end
    end
  end

  describe '#to_s' do
    it 'returns a command string' do
      expect(policy.to_s).to eq "DUPLICATE_POLICY #{policy_key}"
    end

    context 'when overriding the command key' do
      it 'returns the correct string' do
        expect(policy.to_s('ON_DUPLICATE')).to eq "ON_DUPLICATE #{policy_key}"
      end
    end
  end

  describe 'equality' do
    specify 'to each other' do
      expect(policy).to eq described_class.new(policy_key)
    end

    specify 'to strings' do
      expect(policy).to eq policy_key.to_s
    end

    specify 'to symbols' do
      expect(policy).to eq policy_key.to_sym
    end
  end

  describe 'inquiry' do
    specify { expect(policy).to be_block }
    specify { expect(policy).not_to be_max }
  end
end
