# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'Errors' do
  let(:base_error_class) { Redis::TimeSeries::Error }

  describe Redis::TimeSeries::Error do
    it 'exists' do
      expect(described_class).to be
    end

    it { is_expected.to be_a StandardError }
  end

  describe Redis::TimeSeries::InvalidFilters do
    it 'exists' do
      expect(described_class).to be
    end

    it { is_expected.to be_a base_error_class }
  end
end
