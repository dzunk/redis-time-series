[![RSpec](https://github.com/dzunk/redis-time-series/workflows/RSpec/badge.svg)](https://github.com/dzunk/redis-time-series/actions?query=workflow%3ARSpec+branch%3Amaster)
[![Gem Version](https://badge.fury.io/rb/redis-time-series.svg)](https://badge.fury.io/rb/redis-time-series)

# RedisTimeSeries

A Ruby adapter for the [RedisTimeSeries module](https://oss.redislabs.com/redistimeseries).

This doesn't work with vanilla Redis, you need the time series module compiled and installed. Try it with Docker, and see the [module setup guide](https://oss.redislabs.com/redistimeseries/#setup) for additional options.
```
docker run -p 6379:6379 -it --rm redislabs/redistimeseries
```


**TL;DR**
```ruby
require 'redis-time-series'
ts = Redis::TimeSeries.new('foo')
ts.add 1234
=> #<Redis::TimeSeries::Sample:0x00007f8c0d2561d8 @time=2020-06-25 23:23:04 -0700, @value=0.1234e4>
ts.add 56
=> #<Redis::TimeSeries::Sample:0x00007f8c0d26c460 @time=2020-06-25 23:23:16 -0700, @value=0.56e2>
ts.add 78
=> #<Redis::TimeSeries::Sample:0x00007f8c0d276618 @time=2020-06-25 23:23:20 -0700, @value=0.78e2>
ts.range (Time.now.to_i - 100)..Time.now.to_i
=> [#<Redis::TimeSeries::Sample:0x00007f8c0d297200 @time=2020-06-25 23:23:04 -0700, @value=0.1234e4>,
 #<Redis::TimeSeries::Sample:0x00007f8c0d297048 @time=2020-06-25 23:23:16 -0700, @value=0.56e2>,
 #<Redis::TimeSeries::Sample:0x00007f8c0d296e90 @time=2020-06-25 23:23:20 -0700, @value=0.78e2>]
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'redis-time-series'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redis-time-series

## Usage

Check out the Redis Time Series [command documentation](https://oss.redislabs.com/redistimeseries/master/commands/) first. Should be able to do most of that.

### Creating a Series
Create a series (issues `TS.CREATE` command) and return a Redis::TimeSeries object for further use. Key param is required, all other arguments are optional.
```ruby
ts = Redis::TimeSeries.create(
  'your_ts_key',
  labels: { foo: 'bar' },
  retention: 600,
  uncompressed: false,
  redis: Redis.new(url: ENV['REDIS_URL']) # defaults to Redis.current
)
```
You can also call `.new` instead of `.create` to skip the `TS.CREATE` command.
```ruby
ts = Redis::TimeSeries.new('your_ts_key')
```

### Adding Data to a Series
Add a single value
```ruby
ts.add 1234
=> #<Redis::TimeSeries::Sample:0x00007f8c0ea7edc8 @time=2020-06-25 23:41:29 -0700, @value=0.1234e4>
```
Add a single value with a timestamp
```ruby
ts.add 1234, 3.minutes.ago # Used ActiveSupport here, but any Time object works fine
=> #<Redis::TimeSeries::Sample:0x00007fa6ce05f3f8 @time=2020-06-25 23:39:54 -0700, @value=0.1234e4>

# Optionally store data uncompressed
ts.add 5678, uncompressed: true
=> #<Redis::TimeSeries::Sample:0x00007f93f43cdf68 @time=2020-07-18 23:15:29 -0700, @value=0.5678e4>
```
Add multiple values with timestamps
```ruby
ts.madd(2.minutes.ago => 12, 1.minute.ago => 34, Time.now => 56)
=> [1593153909466, 1593153969466, 1593154029466]
```
Increment or decrement the most recent value
```ruby
ts.incrby 2
=> 1593154222877
ts.decrby 1
=> 1593154251392
ts.increment # alias of incrby
=> 1593154255069
ts.decrement # alias of decrby
=> 1593154257344

# Optionally store data uncompressed
ts.incrby 4, uncompressed: true
=> 1595139299769
```
```ruby
ts.get
=> #<Redis::TimeSeries::Sample:0x00007fa25f17ed88 @time=2020-06-25 23:50:57 -0700, @value=0.57e2>
ts.increment
=> 1593154290736
ts.get
=> #<Redis::TimeSeries::Sample:0x00007fa25f199480 @time=2020-06-25 23:51:30 -0700, @value=0.58e2>
```
Add values to multiple series
```ruby
# Without timestamp (series named "foo" and "bar")
Redis::TimeSeries.madd(foo: 1234, bar: 5678)
=> [#<Redis::TimeSeries::Sample:0x00007ffb3aa32ae0 @time=2020-06-26 00:09:15 -0700, @value=0.1234e4>,
 #<Redis::TimeSeries::Sample:0x00007ffb3aa326d0 @time=2020-06-26 00:09:15 -0700, @value=0.5678e4>]
```
```ruby
# With a timestamp
Redis::TimeSeries.madd(foo: { 1.minute.ago => 1234 }, bar: { 1.minute.ago => 2345 })
=> [#<Redis::TimeSeries::Sample:0x00007fb102431f88 @time=2020-06-26 00:10:22 -0700, @value=0.1234e4>,
 #<Redis::TimeSeries::Sample:0x00007fb102431d80 @time=2020-06-26 00:10:22 -0700, @value=0.2345e4>]
```

### Querying a Series
Get the most recent value
```ruby
ts.get
=> #<Redis::TimeSeries::Sample:0x00007fa25f1b78b8 @time=2020-06-25 23:51:30 -0700, @value=0.58e2>
```
Get a range of values
```ruby
# Time range as an argument
ts.range(10.minutes.ago..Time.current)
=> [#<Redis::TimeSeries::Sample:0x00007fa25f13fc28 @time=2020-06-25 23:50:51 -0700, @value=0.57e2>,
    #<Redis::TimeSeries::Sample:0x00007fa25f13db58 @time=2020-06-25 23:50:55 -0700, @value=0.58e2>,
    #<Redis::TimeSeries::Sample:0x00007fa25f13d900 @time=2020-06-25 23:50:57 -0700, @value=0.57e2>,
    #<Redis::TimeSeries::Sample:0x00007fa25f13d680 @time=2020-06-25 23:51:30 -0700, @value=0.58e2>]

# Time range as keyword args
ts.range(from: 10.minutes.ago, to: Time.current)
=> [#<Redis::TimeSeries::Sample:0x00007fa25dc01f00 @time=2020-06-25 23:50:51 -0700, @value=0.57e2>,
    #<Redis::TimeSeries::Sample:0x00007fa25dc01d20 @time=2020-06-25 23:50:55 -0700, @value=0.58e2>,
    #<Redis::TimeSeries::Sample:0x00007fa25dc01b68 @time=2020-06-25 23:50:57 -0700, @value=0.57e2>,
    #<Redis::TimeSeries::Sample:0x00007fa25dc019b0 @time=2020-06-25 23:51:30 -0700, @value=0.58e2>]

# Limit number of results with count argument
ts.range(10.minutes.ago..Time.current, count: 2)
=> [#<Redis::TimeSeries::Sample:0x00007fa25dc01f00 @time=2020-06-25 23:50:51 -0700, @value=0.57e2>,
    #<Redis::TimeSeries::Sample:0x00007fa25dc01d20 @time=2020-06-25 23:50:55 -0700, @value=0.58e2>]

# Apply aggregations to the range
ts.range(from: 10.minutes.ago, to: Time.current, aggregation: [:avg, 10.minutes])
=> [#<Redis::TimeSeries::Sample:0x00007fa25dc01f00 @time=2020-06-25 23:50:00 -0700, @value=0.575e2>]
```
Get info about the series
```ruby
ts.info
=> #<struct Redis::TimeSeries::Info
 total_samples=3,
 memory_usage=4184,
 first_timestamp=1594060993011,
 last_timestamp=1594060993060,
 retention_time=0,
 chunk_count=1,
 max_samples_per_chunk=256,
 labels={"foo"=>"bar"},
 source_key=nil,
 rules=[]>
# Each info property is also a method on the time series object
ts.memory_usage
=> 4208
ts.labels
=> {"foo"=>"bar"}
ts.total_samples
=> 3
# Total samples also available as #count, #length, and #size
ts.count
=> 3
ts.length
=> 3
ts.size
=> 3
```
Find series matching specific label(s)
```ruby
Redis::TimeSeries.query_index('foo=bar')
=> [#<Redis::TimeSeries:0x00007fc115ba1610
  @key="ts3",
  @redis=#<Redis client v4.2.1 for redis://127.0.0.1:6379/0>,
  @retention=nil,
  @uncompressed=false>]
# Note that you need at least one "label equals value" filter
Redis::TimeSeries.query_index('foo!=bar')
=> RuntimeError: Filtering requires at least one equality comparison
# query_index is also aliased as .where for fluency
Redis::TimeSeries.where('foo=bar')
=> [#<Redis::TimeSeries:0x00007fb8981010c8
  @key="ts3",
  @redis=#<Redis client v4.2.1 for redis://127.0.0.1:6379/0>,
  @retention=nil,
  @uncompressed=false>]
```
### Filter DSL
You can provide filter strings directly, per the time series documentation.
```ruby
Redis::TimeSeries.where('foo=bar')
=> [#<Redis::TimeSeries:0x00007fb8981010c8...>]
```
There is also a hash-based syntax available, which may be more pleasant to work with.
```ruby
Redis::TimeSeries.where(foo: 'bar')
=> [#<Redis::TimeSeries:0x00007fb89811dca0...>]
```
All six filter types are represented in hash format below.
```ruby
{
  foo: 'bar',          # label=value  (equality)
  foo: { not: 'bar' }, # label!=value (inequality)
  foo: true,           # label=       (presence)
  foo: false,          # label!=      (absence)
  foo: [1, 2],         # label=(1,2)  (any value)
  foo: { not: [1, 2] } # label!=(1,2) (no values)
}
```
Note the special use of `true` and `false`. If you're representing a boolean value with a label, rather than setting its value to "true" or "false" (which would be treated as strings in Redis anyway), you should add or remove the label from the series.

Values can be any object that responds to `.to_s`:
```ruby
class Person
  def initialize(name)
    @name = name
  end

  def to_s
    @name
  end
end

Redis::TimeSeries.where(person: Person.new('John'))
#=> TS.QUERYINDEX person=John
```

### Compaction Rules
Add a compaction rule to a series.
```ruby
# Destintation time series needs to be created before the rule is added.
other_ts = Redis::TimeSeries.create('other_ts')

# Aggregation buckets are measured in milliseconds
ts.create_rule(dest: other_ts, aggregation: [:count, 60000]) # 1 minute

# Can provide a string key instead of a time series object
ts.create_rule(dest: 'other_ts', aggregation: [:avg, 120000])

# If you're using Rails or ActiveSupport, you can provide an
# ActiveSupport::Duration instead of an integer
ts.create_rule(dest: other_ts, aggregation: [:avg, 2.minutes])

# Can also provide an Aggregation object instead of an array
agg = Redis::TimeSeries::Aggregation.new(:avg, 120000)
ts.create_rule(dest: other_ts, aggregation: agg)

# Class-level method also available
Redis::TimeSeries.create_rule(source: ts, dest: other_ts, aggregation: ['std.p', 150000])
```
Remove an existing compaction rule
```ruby
ts.delete_rule(dest: 'other_ts')
Redis::TimeSeries.delete_rule(source: ts, dest: 'other_ts')
```


### TODO
* `TS.REVRANGE`
* `TS.MRANGE`/`TS.MREVRANGE`
* Probably a bunch more stuff

## Development

After checking out the repo, run `bin/setup`. You need the `docker` daemon installed and running. This script will:
* Install gem dependencies
* Pull the latest `redislabs/redistimeseries` image
* Start a Redis server on port 6379
* Seed three time series with some sample data
* Attach to the running server and print logs to `STDOUT`

With the above script running, or after starting a server manually, you can run `bin/console` to interact with it. The three series are named `ts1`, `ts2`, and `ts3`, and are available as instance variables in the console.

If you want to see the commands being executed, run the console with `DEBUG=true bin/console` and it will output the raw command strings as they're executed.
```ruby
[1] pry(main)> @ts1.increment
DEBUG: TS.INCRBY ts1 1
=> 1593159795467
[2] pry(main)> @ts1.get
DEBUG: TS.GET ts1
=> #<Redis::TimeSeries::Sample:0x00007f8e1a190cf8 @time=2020-06-26 01:23:15 -0700, @value=0.4e1>
```

Use `rake spec` to run the test suite.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dzunk/redis-time-series.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
