# frozen_string_literal: true
RSpec.describe Redis::TimeSeries do
  subject(:ts) { described_class.create(key) }

  let(:key) { 'time_series_test' }
  let(:time) { 1591339859 }

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

  describe 'TS.ALTER' do
    context 'altering the retention period' do
      specify do
        expect { ts.retention = 1234 }.to issue_command "TS.ALTER #{key} RETENTION 1234"
      end
    end

    context 'altering the labels' do
      specify do
        expect { ts.labels = { foo: 'bar' } }.to issue_command \
          "TS.ALTER #{key} LABELS foo bar"
      end
    end
  end

  describe 'TS.ADD' do
    context 'without a timestamp' do
      specify do
        expect { ts.add 123 }.to issue_command "TS.ADD #{key} * 123"
      end
    end

    context 'with a timestamp' do
      specify do
        expect { ts.add 123, time }.to issue_command "TS.ADD #{key} #{time} 123"
      end
    end

    context 'with an invalid value' do
      specify { expect { ts.add 'bar' }.to raise_error Redis::CommandError }
    end
  end

  describe 'TS.MADD' do
    let(:madd) { ts.madd(values) }

    context 'with a hash of timestamps and values' do
      specify do
        expect { ts.madd(1591339859 => 12, 1591339860 => 34) }.to issue_command \
          "TS.MADD #{key} 1591339859 12 #{key} 1591339860 34"
      end
    end

    context 'with an array of values' do
      specify do
        expect { ts.madd [56, 78, 9] }.to issue_command \
          "TS.MADD #{key} * 56 #{key} * 78 #{key} * 9"
      end
    end

    context 'passed values directly' do
      specify do
        expect { ts.madd 1, 2, 3 }.to issue_command \
          "TS.MADD #{key} * 1 #{key} * 2 #{key} * 3"
      end
    end
  end

  describe 'TS.INCRBY' do
    specify { expect { ts.incrby 1 }.to issue_command "TS.INCRBY #{key} 1" }

    context 'with a timestamp' do
      specify { expect { ts.incrby 1, time }.to issue_command "TS.INCRBY #{key} 1 #{time}" }
    end
  end

  describe 'TS.DECRBY' do
    specify { expect { ts.decrby 1 }.to issue_command "TS.DECRBY #{key} 1" }

    context 'with a timestamp' do
      specify { expect { ts.decrby 1, time }.to issue_command "TS.DECRBY #{key} 1 #{time}" }
    end
  end

  describe 'TS.CREATERULE'
  describe 'TS.DELETERULE'

  describe 'TS.RANGE'
  describe 'TS.MRANGE'
  describe 'TS.GET'
  describe 'TS.MGET'

  describe 'TS.INFO' do
    subject(:info) { ts.info }

    specify { expect { info }.to issue_command "TS.INFO #{key}" }

    it 'returns an info hash' do
      expect(info).to eq(
        {
          'total_samples' => 0,
          'memory_usage' => 4184,
          'first_timestamp' => 0,
          'last_timestamp' => 0,
          'retention_time' => 0,
          'chunk_count' => 1,
          'max_samples_per_chunk' => 256,
          'labels' => [],
          'source_key' => nil,
          'rules' => []
        }
      )
    end
  end

  describe 'TS.QUERYINDEX'
end
