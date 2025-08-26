# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Redis::TimeSeries::Rule do
  subject(:rule) do
    described_class.new(
      data: [destination.key, aggregation.duration, aggregation.type],
      source: source
    )
  end

  let(:source) { Redis::TimeSeries.new_or_create('test_rule_source') }
  let(:destination) { Redis::TimeSeries.new_or_create('test_rule_dest') }
  let(:aggregation) { Redis::TimeSeries::Aggregation.new(:avg, 10.minutes) }

  before do
    source.create_rule dest: destination, aggregation: aggregation
  end

  after do
    source.destroy
    destination.destroy
  end

  describe '#initialize' do
    it 'requires a source and rule data' do
      expect { described_class.new }.to raise_error ArgumentError
      expect { described_class.new(data: ['foo', 3, 'avg'], source: source) }.not_to raise_error
    end
  end

  describe '#aggregation' do
    subject { rule.aggregation }

    it { is_expected.to eq aggregation }
  end

  describe '#destination' do
    subject { rule.destination }

    it { is_expected.to eq destination }
  end

  describe '#dest' do
    it 'is an alias for #destination' do
      expect(rule.dest).to eq rule.destination
    end
  end

  describe '#delete' do
    subject { -> { rule.delete } }

    it { is_expected.to issue_command "TS.DELETERULE #{source.key} #{destination.key}" }
  end

  describe '#source_key' do
    subject { rule.source_key }

    it { is_expected.to eq source.key }
  end
end
