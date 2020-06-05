# frozen_string_literal: true
RSpec.describe Redis::TimeSeries do
  subject(:ts) { described_class.create(key) }

  let(:key) { 'time_series_test' }

  after { Redis.current.del key }

  describe 'TS.CREATE' do
    subject(:create) { described_class.create(key, **options) }
    let(:options) { {} }

    context 'with no arguments' do
      specify do
        expect { described_class.create }.to raise_error ArgumentError
      end
    end

    context 'with a key name' do
      specify do
        expect { create }.to issue_command "TS.CREATE #{key}"
      end
    end

    context 'with a retention time' do
      let(:options) { { retention: 1234 } }

      specify do
        expect { create }.to issue_command "TS.CREATE #{key} RETENTION 1234"
      end
    end

    context 'with compression disabled' do
      let(:options) { { uncompressed: true } }

      specify do
        expect { create }.to issue_command "TS.CREATE #{key} UNCOMPRESSED"
      end
    end

    context 'with labels' do
      let(:options) { { labels: { foo: 'bar', baz: 1, plugh: true } } }

      specify do
        expect { create }.to issue_command "TS.CREATE #{key} LABELS foo bar baz 1 plugh true"
      end
    end

    context 'with all available options' do
      let(:options) do
        {
          retention: 5678,
          uncompressed: true,
          labels: { xyzzy: 'zork' }
        }
      end

      specify do
        expect { create }.to issue_command \
          "TS.CREATE #{key} RETENTION 5678 UNCOMPRESSED LABELS xyzzy zork"
      end
    end
  end

  describe 'TS.ALTER'
  describe 'TS.ADD'
  describe 'TS.MADD'
  describe 'TS.INCRBY'
  describe 'TS.DECRBY'

  describe 'TS.CREATERULE'
  describe 'TS.DELETERULE'

  describe 'TS.RANGE'
  describe 'TS.MRANGE'
  describe 'TS.GET'
  describe 'TS.MGET'

  describe 'TS.INFO'
  describe 'TS.QUERYINDEX'
end
