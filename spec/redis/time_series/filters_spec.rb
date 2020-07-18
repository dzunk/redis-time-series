# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Redis::TimeSeries::Filters do
  subject(:filters) { described_class.new(value) }

  let(:value) { string_value }
  let(:string_value) { 'foo=bar baz!=quux plugh= xyzzy!= zork=(grue,cyclops) barrow!=(wizard,frobozz)' }
  let(:hash_value) do
    {
      foo: 'bar',
      baz: { not: 'quux' },
      plugh: false,
      xyzzy: true,
      zork: ['grue', 'cyclops'],
      barrow: { not: ['wizard', 'frobozz'] }
    }
  end

  shared_examples 'parsing and serialization' do |expected_string|
    context 'with a string' do
      let(:value) { string_value }

      it 'correctly parses' do
        expect(filters.size).to eq 1
      end

      it 'correctly serializes' do
        expect(filters.map(&:to_s)).to contain_exactly expected_string
      end
    end

    context 'with a hash' do
      let(:value) { hash_value }

      it 'correctly parses' do
        expect(filters.size).to eq 1
      end

      it 'correctly serializes' do
        expect(filters.map(&:to_s)).to contain_exactly expected_string
      end
    end
  end

  context 'equality filter' do
    let(:filters) { super().equal }

    include_examples 'parsing and serialization', 'foo=bar'
  end

  context 'inequality filter' do
    let(:filters) { super().not_equal }

    include_examples 'parsing and serialization', 'baz!=quux'
  end


  context 'absence filter' do
    let(:filters) { super().absent }

    include_examples 'parsing and serialization', 'plugh='
  end

  context 'presence filter' do
    let(:filters) { super().present }

    include_examples 'parsing and serialization', 'xyzzy!='
  end

  context 'any value filter' do
    let(:filters) { super().any_value }

    include_examples 'parsing and serialization', 'zork=(grue,cyclops)'
  end

  context 'no values filter' do
    let(:filters) { super().no_values }

    include_examples 'parsing and serialization', 'barrow!=(wizard,frobozz)'
  end

  describe '#valid?' do
    context 'with at least one equality filter' do
      let(:value) { 'foo=bar' }

      it { is_expected.to be_valid }
    end

    context 'with no equality filter' do
      let(:value) { 'foo!=bar baz=' }

      it { is_expected.not_to be_valid }
    end

    context 'with no filters' do
      let(:value) { nil }

      it { is_expected.not_to be_valid }
    end
  end

  describe '#validate!' do
    context 'when valid' do
      let(:value) { 'foo=bar' }

      it 'returns true' do
        expect(filters.validate!).to be true
      end
    end

    context 'when invalid' do
      let(:value) { nil }

      it 'raises an error' do
        expect { filters.validate! }.to raise_error Redis::TimeSeries::InvalidFilters
      end
    end
  end

  describe '#to_a' do
    it 'returns the parsed filters as an array of strings' do
      expect(filters.to_a).to match_array value.split(' ')
    end
  end

  describe '#to_h' do
    let(:value) { string_value }

    it 'returns the parsed filters as a hash' do
      expect(filters.to_h).to eq hash_value.transform_keys(&:to_s)
    end
  end

  describe '#to_s' do
    let(:value) { hash_value }

    it 'returns the parsed filters as a single string' do
      expect(filters.to_s).to eq string_value
    end
  end

  describe 'errors' do
    context 'when given an invalid filter string' do
      let(:value) { 'foo' }

      specify { expect { filters }.to raise_error Redis::TimeSeries::InvalidFilters }
    end

    context 'when given an invalid hash value' do
      let(:value) { { foo: { bar: 'baz' } } }

      specify { expect { filters }.to raise_error Redis::TimeSeries::InvalidFilters }
    end
  end
end
