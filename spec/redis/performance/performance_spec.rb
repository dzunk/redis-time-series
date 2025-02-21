require "benchmark"
include Benchmark

# ! to run only this spec use the following: rspec -P **/performance/*.rb

RSpec.describe Redis::TimeSeries do
  # runtimes is the count of times a test is repeated to ensure acturate results
  let(:runtimes) { 100 }
  # days is the period on wich data is added to the dataset and on the period the test is run on
  let(:days) { 366 }

  subject(:ts) { described_class.new_or_create(key) }

  subject(:ts_avg) { described_class.new_or_create(avg_key) }

  let(:key) { "time_series_performance" }
  let(:avg_key) { "time_series_performance_avg" }

  let(:time) { 1_591_339_859 }
  let(:from) { Time.at(time) }
  let(:to) { Time.at(time) + days.days }

  # remove the key after the test
  after { redis.with { |conn| conn.del(key) } }

  # getData adds random data for the from to to at period interval. to the database
  def getData(period)
    rd = Random.new
    data = {}
    (from.to_i..to.to_i).step(period) do |date|
      data[msec(date)] = msec(rd.rand)
    end
    puts "added data with length: " + data.length.to_s
    data.each_slice(100_000) { |result| ts.madd(result.to_h) }
  end

  # avg all the results
  def avg_tms(array)
    result = array.shift
    array.each { |total| result = result + total }
    result / runtimes
  end

  # convert to msec
  def msec(timeStamp)
    (timeStamp.to_f * 1000).to_i
  end

  # run the test and get data for every period. example is 15min get every 15 min of data from start to end.
  def run_test(period)
    totals = []
    results = nil
    runtimes.times do
      totals << Benchmark.measure do
        results = ts.range(msec(from)..msec(to), aggregation: [:avg, period ])
      end
    end
    puts "total for " + results.length.to_s + " results " + period.parts.to_s + " | " + avg_tms(totals).format
  end

  # gets the period from start to end but limits at times. does not do this with redis but just from start adds the period and does that times times
  def run_test_times(period, times)
    totals = []
    results = nil
    runtimes.times do
      totals << Benchmark.measure do
        results = ts.range(msec(from)..msec(from + (period * times)), aggregation: [:avg, period ])
      end
    end
    puts "total for " + results.length.to_s + " results " + period.parts.to_s + " | run times: " + times.to_s + " | " + avg_tms(totals).format
  end

  # examples of tests to run.
  describe "same period of from to" do
    it "puts the time taken for raw data" do
      # # first get the data that you want in the data set in this case 30 second period
      # getData(30.seconds)

      # # run the test and get data for the following intervals
      # run_test(1.hour)
      # run_test(12.hour)
      # run_test(1.day)
      # run_test(7.day)
      # run_test(30.days)
      # run_test(366.days)

      # run_test_times(1.hour, 100)
    end
  end
end
