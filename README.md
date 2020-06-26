# RedisTimeSeries

A Ruby adapter for the [RedisTimeSeries module](https://oss.redislabs.com/redistimeseries).

This doesn't work with vanilla Redis, you need the time series module compiled and installed. Try it with Docker, and see the [module setup guide](https://oss.redislabs.com/redistimeseries/#setup) for additional options.
```
docker run -p 6379:6379 -it --rm redislabs/redistimeseries
```


**TL;DR**
```ruby
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
  labels: ['foo', 'bar'],
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
ts.range 10.minutes.ago..Time.current # Time range as an argument
=> [#<Redis::TimeSeries::Sample:0x00007fa25f13fc28 @time=2020-06-25 23:50:51 -0700, @value=0.57e2>,
 #<Redis::TimeSeries::Sample:0x00007fa25f13db58 @time=2020-06-25 23:50:55 -0700, @value=0.58e2>,
 #<Redis::TimeSeries::Sample:0x00007fa25f13d900 @time=2020-06-25 23:50:57 -0700, @value=0.57e2>,
 #<Redis::TimeSeries::Sample:0x00007fa25f13d680 @time=2020-06-25 23:51:30 -0700, @value=0.58e2>]
ts.range from: 10.minutes.ago, to: Time.current # Time range as keyword args
=> [#<Redis::TimeSeries::Sample:0x00007fa25dc01f00 @time=2020-06-25 23:50:51 -0700, @value=0.57e2>,
 #<Redis::TimeSeries::Sample:0x00007fa25dc01d20 @time=2020-06-25 23:50:55 -0700, @value=0.58e2>,
 #<Redis::TimeSeries::Sample:0x00007fa25dc01b68 @time=2020-06-25 23:50:57 -0700, @value=0.57e2>,
 #<Redis::TimeSeries::Sample:0x00007fa25dc019b0 @time=2020-06-25 23:51:30 -0700, @value=0.58e2>]
```

### TODO
* `TS.REVRANGE`
* `TS.MRANGE`/`TS.MREVRANGE`
* `TS.QUERYINDEX`
* Compaction rules
* Filters
* Probably a bunch more stuff

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dzunk/redis-time-series.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
