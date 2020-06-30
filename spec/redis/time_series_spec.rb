# frozen_string_literal: true
RSpec.describe Redis::TimeSeries do
  subject(:ts) { described_class.create(key) }

  let(:key) { 'time_series_test' }
  let(:time) { 1591339859 }
  let(:from) { time }
  let(:to) { time + 120 }

  after { Redis.current.del key }

  def msec(ts)
    (ts.to_f * 1000).to_i
  end

  describe 'TS.CREATE' do
    subject(:ts) { described_class.new(key) }

    let(:create) { described_class.create(key, **options) }
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
        expect(ts.info['labels']).to eq [
          # TODO: cast values
          ['foo', 'bar'],
          ['baz', '1'],
          ['plugh', 'true']
        ]
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
        expect(ts.info['labels']).to eq [['foo', 'bar']]
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

    it 'returns the added Sample' do
      s = ts.add 123
      expect(s).to be_a Redis::TimeSeries::Sample
      expect(s.value).to eq 123
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
      let(:time) { Time.now }
      let(:ts_msec) { time.to_i * 1000 }

      before { travel_to time } # TODO: freeze_time metadata
      after { travel_back }

      specify do
        expect { ts.madd [56, 78, 9] }.to issue_command \
          "TS.MADD #{key} #{ts_msec} 56 #{key} #{ts_msec + 1} 78 #{key} #{ts_msec + 2} 9"
      end
    end

    context 'passed values directly' do
      let(:time) { Time.now }
      let(:ts_msec) { time.to_i * 1000 }

      before { travel_to time }
      after { travel_back }

      specify do
        expect { ts.madd 1, 2, 3 }.to issue_command \
          "TS.MADD #{key} #{ts_msec} 1 #{key} #{ts_msec + 1} 2 #{key} #{ts_msec + 2} 3"
      end
    end

    describe 'with multiple series' do
      specify do
        expect { described_class.madd(foo: 1, bar: 2, baz: 3) }.to issue_command \
          "TS.MADD foo * 1 bar * 2 baz * 3"
      end

      specify do
        expect do
          described_class.madd(foo: { 123 => 1 }, bar: { 456 => 2, 678 => 3 })
        end.to issue_command "TS.MADD foo 123 1 bar 456 2 bar 678 3"
      end

      specify do
        expect do
          described_class.madd(foo: [123, 1], bar: [[456, 2], [678, 3]])
        end.to issue_command "TS.MADD foo 123 1 bar 456 2 bar 678 3"
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

  describe 'TS.RANGE' do
    specify do
      expect { ts.range from: from, to: to }.to issue_command "TS.RANGE #{key} #{msec from} #{msec to}"
    end

    context 'given a range' do
      specify do
        expect { ts.range from..to }.to issue_command "TS.RANGE #{key} #{msec from} #{msec to}"
      end
    end

    context 'with a maximum result count' do
      specify do
        expect { ts.range from..to, count: 10 }.to issue_command \
          "TS.RANGE #{key} #{msec from} #{msec to} COUNT 10"
      end
    end

    context 'with an aggregation' # TODO

    it 'returns an array of Samples' do
      values = [2, 4, 6]
      ts.madd values
      results = ts.range(1.minute.ago..1.minute.from_now)
      expect(results.size).to eq 3
      expect(results.map(&:value)).to eq values
    end
  end

  describe 'TS.MRANGE' # TODO: class method for querying multiple time-series

  describe 'TS.GET' do
    specify { expect { ts.get }.to issue_command "TS.GET #{key}" }

    it 'returns a Sample' do
      timestamp = ts.increment
      expect(ts.get).to be_a Redis::TimeSeries::Sample
      expect(ts.get.ts_msec).to eq timestamp
    end
  end

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
