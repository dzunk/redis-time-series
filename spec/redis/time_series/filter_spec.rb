# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Redis::TimeSeries::Filter do
  subject(:filter) { described_class.new(filter_string) }

  let(:filter_string) { 'foo=bar baz!=quux plugh= xyzzy!= zork=(grue,cyclops) barrow!=(wizard,frobozz)' }

  shared_examples 'parsing and serialization' do |expected_string|
    it 'correctly parses' do
      expect(filters.size).to eq 1
    end

    it 'correctly serializes' do
      expect(filters.map(&:to_s)).to contain_exactly expected_string
    end
  end

  context 'equality filter' do
    subject(:filters) { filter.equal_filters }

    include_examples 'parsing and serialization', 'foo=bar'
  end

  context 'inequality filter' do
    subject(:filters) { filter.not_equal_filters }

    include_examples 'parsing and serialization', 'baz!=quux'
  end


  context 'absence filter' do
    subject(:filters) { filter.absent_filters }

    include_examples 'parsing and serialization', 'plugh='
  end

  context 'presence filter' do
    subject(:filters) { filter.present_filters }

    include_examples 'parsing and serialization', 'xyzzy!='
  end

  context 'any value filter' do
    subject(:filters) { filter.any_value_filters }

    include_examples 'parsing and serialization', 'zork=(grue,cyclops)'
  end

  context 'no values filter' do
    subject(:filters) { filter.no_values_filters }

    include_examples 'parsing and serialization', 'barrow!=(wizard,frobozz)'
  end

  describe '#valid?' do
    context 'with at least one equality filter' do
      let(:filter_string) { 'foo=bar' }

      it { is_expected.to be_valid }
    end

    context 'with no equality filter' do
      let(:filter_string) { 'foo!=bar baz=' }

      it { is_expected.not_to be_valid }
    end

    context 'with no filters' do
      let(:filter_string) { nil }

      it { is_expected.not_to be_valid }
    end
  end

  describe '#validate!' do
    context 'when valid' do
      let(:filter_string) { 'foo=bar' }

      it 'returns true' do
        expect(filter.validate!).to be true
      end
    end

    context 'when invalid' do
      let(:filter_string) { nil }

      it 'raises an error' do
        # TODO: custom error class
        expect { filter.validate! }.to raise_error RuntimeError
      end
    end
  end
end
